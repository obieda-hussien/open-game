extends Node

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULTS := {
	"display/target_fps": 60,
	"display/vsync": false,
	"graphics/preset": "balanced",
	"graphics/dynamic_resolution": true,
	"graphics/render_scale": 0.85,
	"graphics/render_scale_min": 0.60,
	"graphics/render_scale_max": 1.00,
	"graphics/msaa": 2,
	"graphics/fxaa": true,
	"graphics/shadows": 1,
	"graphics/draw_distance": 2,
	"graphics/vegetation_density": 0.65,
	"graphics/npc_density": 0.60,
	"graphics/traffic_density": 0.55,
	"graphics/effects_quality": 1,
	"audio/master": 0.90,
	"audio/music": 0.72,
	"audio/sfx": 0.90,
	"audio/voice": 1.00,
	"audio/ambience": 0.78,
	"gameplay/camera_sensitivity": 0.18,
	"gameplay/invert_y": false,
	"gameplay/vibration": true,
	"gameplay/subtitles": true,
	"gameplay/show_touch_controls": false,
	"accessibility/reduce_camera_shake": false
}

const PRESETS := {
	"battery": {
		"display/target_fps": 30,
		"graphics/dynamic_resolution": true,
		"graphics/render_scale": 0.68,
		"graphics/render_scale_min": 0.52,
		"graphics/render_scale_max": 0.78,
		"graphics/msaa": 0,
		"graphics/fxaa": true,
		"graphics/shadows": 0,
		"graphics/draw_distance": 1,
		"graphics/vegetation_density": 0.30,
		"graphics/npc_density": 0.30,
		"graphics/traffic_density": 0.25,
		"graphics/effects_quality": 0
	},
	"balanced": {
		"display/target_fps": 45,
		"graphics/dynamic_resolution": true,
		"graphics/render_scale": 0.82,
		"graphics/render_scale_min": 0.60,
		"graphics/render_scale_max": 0.95,
		"graphics/msaa": 2,
		"graphics/fxaa": true,
		"graphics/shadows": 1,
		"graphics/draw_distance": 2,
		"graphics/vegetation_density": 0.60,
		"graphics/npc_density": 0.55,
		"graphics/traffic_density": 0.50,
		"graphics/effects_quality": 1
	},
	"high": {
		"display/target_fps": 60,
		"graphics/dynamic_resolution": true,
		"graphics/render_scale": 0.92,
		"graphics/render_scale_min": 0.70,
		"graphics/render_scale_max": 1.00,
		"graphics/msaa": 2,
		"graphics/fxaa": true,
		"graphics/shadows": 2,
		"graphics/draw_distance": 3,
		"graphics/vegetation_density": 0.85,
		"graphics/npc_density": 0.80,
		"graphics/traffic_density": 0.75,
		"graphics/effects_quality": 2
	},
	"ultra": {
		"display/target_fps": 60,
		"graphics/dynamic_resolution": false,
		"graphics/render_scale": 1.00,
		"graphics/render_scale_min": 0.85,
		"graphics/render_scale_max": 1.00,
		"graphics/msaa": 4,
		"graphics/fxaa": true,
		"graphics/shadows": 2,
		"graphics/draw_distance": 4,
		"graphics/vegetation_density": 1.00,
		"graphics/npc_density": 1.00,
		"graphics/traffic_density": 1.00,
		"graphics/effects_quality": 2
	}
}

var values: Dictionary = DEFAULTS.duplicate(true)

func _ready() -> void:
	load_settings()
	apply_all()

func get_value(key: String, fallback: Variant = null) -> Variant:
	return values.get(key, fallback)

func set_value(key: String, value: Variant, persist: bool = true) -> void:
	values[key] = value
	_apply_one(key, value)
	EventBus.setting_changed.emit(key, value)
	if persist:
		save_settings()

func apply_graphics_preset(preset_name: String) -> void:
	if not PRESETS.has(preset_name):
		return
	values["graphics/preset"] = preset_name
	for key in PRESETS[preset_name]:
		values[key] = PRESETS[preset_name][key]
		_apply_one(key, values[key])
		EventBus.setting_changed.emit(key, values[key])
	EventBus.setting_changed.emit("graphics/preset", preset_name)
	save_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in values:
		config.set_value("settings", key, values[key])
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Could not save settings: %s" % error_string(err))

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key in DEFAULTS:
		if config.has_section_key("settings", key):
			values[key] = config.get_value("settings", key, DEFAULTS[key])

func apply_all() -> void:
	for key in values:
		_apply_one(key, values[key])

func _apply_one(key: String, value: Variant) -> void:
	match key:
		"display/target_fps":
			Engine.max_fps = int(value)
		"display/vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if bool(value) else DisplayServer.VSYNC_DISABLED
			)
		"graphics/render_scale":
			get_tree().root.scaling_3d_scale = clampf(float(value), 0.5, 1.0)
		"graphics/msaa":
			match int(value):
				2:
					get_tree().root.msaa_3d = Viewport.MSAA_2X
				4:
					get_tree().root.msaa_3d = Viewport.MSAA_4X
				8:
					get_tree().root.msaa_3d = Viewport.MSAA_8X
				_:
					get_tree().root.msaa_3d = Viewport.MSAA_DISABLED
		"graphics/fxaa":
			get_tree().root.screen_space_aa = (
				Viewport.SCREEN_SPACE_AA_FXAA if bool(value)
				else Viewport.SCREEN_SPACE_AA_DISABLED
			)
		"audio/master":
			_set_bus_volume("Master", float(value))
		"audio/music":
			_set_bus_volume("Music", float(value))
		"audio/sfx":
			_set_bus_volume("SFX", float(value))
		"audio/voice":
			_set_bus_volume("Voice", float(value))
		"audio/ambience":
			_set_bus_volume("Ambience", float(value))
		_:
			pass

func _set_bus_volume(bus_name: String, linear: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var safe_linear := clampf(linear, 0.0001, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(safe_linear))
	AudioServer.set_bus_mute(bus_index, linear <= 0.0001)
