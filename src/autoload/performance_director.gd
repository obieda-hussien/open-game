extends Node

const SAMPLE_WINDOW := 1.25
const SCALE_STEP := 0.04
const PRESSURE_SMOOTHING := 0.08

var _sample_time := 0.0
var _frame_time_ema := 16.6
var _pressure := 0.0
var _slow_streak := 0
var _fast_streak := 0
var _tier := "balanced"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.setting_changed.connect(_on_setting_changed)
	_tier = String(Settings.get_value("graphics/preset", "balanced"))
	_apply_target_fps()

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var frame_ms := delta * 1000.0
	_frame_time_ema = lerpf(_frame_time_ema, frame_ms, 0.06)
	_sample_time += delta
	if _sample_time < SAMPLE_WINDOW:
		return
	_sample_time = 0.0

	var target_fps := max(20, int(Settings.get_value("display/target_fps", 45)))
	var target_ms := 1000.0 / float(target_fps)
	var raw_pressure := clampf((_frame_time_ema - target_ms) / maxf(target_ms, 1.0), -1.0, 1.5)
	_pressure = lerpf(_pressure, raw_pressure, PRESSURE_SMOOTHING * 4.0)
	WorldState.performance_pressure = _pressure

	if bool(Settings.get_value("graphics/dynamic_resolution", true)):
		_adapt_render_scale(target_ms)

	var scale := get_tree().root.scaling_3d_scale
	EventBus.performance_changed.emit(scale, _pressure, _tier)

func _adapt_render_scale(target_ms: float) -> void:
	var viewport := get_tree().root
	var current := viewport.scaling_3d_scale
	var minimum := float(Settings.get_value("graphics/render_scale_min", 0.60))
	var maximum := float(Settings.get_value("graphics/render_scale_max", 1.00))

	if _frame_time_ema > target_ms * 1.08:
		_slow_streak += 1
		_fast_streak = 0
	elif _frame_time_ema < target_ms * 0.82:
		_fast_streak += 1
		_slow_streak = 0
	else:
		_slow_streak = 0
		_fast_streak = 0

	if _slow_streak >= 2:
		viewport.scaling_3d_scale = clampf(current - SCALE_STEP, minimum, maximum)
		_slow_streak = 0
	elif _fast_streak >= 4:
		viewport.scaling_3d_scale = clampf(current + SCALE_STEP, minimum, maximum)
		_fast_streak = 0

func quality_multiplier() -> float:
	if _pressure > 0.35:
		return 0.58
	if _pressure > 0.12:
		return 0.78
	return 1.0

func frame_time_ms() -> float:
	return _frame_time_ema

func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "display/target_fps":
		_apply_target_fps()
	elif key == "graphics/preset":
		_tier = String(value)
	elif key == "graphics/render_scale" and not bool(Settings.get_value("graphics/dynamic_resolution", true)):
		get_tree().root.scaling_3d_scale = float(value)

func _apply_target_fps() -> void:
	Engine.max_fps = int(Settings.get_value("display/target_fps", 45))
