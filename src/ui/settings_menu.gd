class_name SettingsMenu
extends Control

var _graphics_tab: VBoxContainer
var _audio_tab: VBoxContainer
var _gameplay_tab: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
	get_tree().paused = false
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.018, 0.024, 0.036, 0.96)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)

	_graphics_tab = _make_tab(tabs, "Graphics")
	_audio_tab = _make_tab(tabs, "Audio")
	_gameplay_tab = _make_tab(tabs, "Gameplay")

	_build_graphics()
	_build_audio()
	_build_gameplay()

func _make_tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	return box

func _build_graphics() -> void:
	_add_option(_graphics_tab, "Preset", "graphics/preset", ["battery", "balanced", "high", "ultra", "custom"])
	_add_option(_graphics_tab, "Frame cap", "display/target_fps", [30, 45, 60, 90, 120])
	_add_check(_graphics_tab, "VSync", "display/vsync")
	_add_check(_graphics_tab, "Dynamic resolution", "graphics/dynamic_resolution")
	_add_slider(_graphics_tab, "Render scale", "graphics/render_scale", 0.50, 1.00, 0.01)
	_add_slider(_graphics_tab, "Minimum dynamic scale", "graphics/render_scale_min", 0.50, 0.95, 0.01)
	_add_slider(_graphics_tab, "Maximum dynamic scale", "graphics/render_scale_max", 0.65, 1.00, 0.01)
	_add_option(_graphics_tab, "MSAA", "graphics/msaa", [0, 2, 4, 8])
	_add_check(_graphics_tab, "FXAA", "graphics/fxaa")
	_add_option(_graphics_tab, "Shadow quality", "graphics/shadows", [0, 1, 2])
	_add_option(_graphics_tab, "World draw distance", "graphics/draw_distance", [1, 2, 3, 4])
	_add_slider(_graphics_tab, "Vegetation density", "graphics/vegetation_density", 0.0, 1.0, 0.05)
	_add_slider(_graphics_tab, "NPC density", "graphics/npc_density", 0.0, 1.0, 0.05)
	_add_slider(_graphics_tab, "Traffic density", "graphics/traffic_density", 0.0, 1.0, 0.05)
	_add_option(_graphics_tab, "Effects quality", "graphics/effects_quality", [0, 1, 2])

func _build_audio() -> void:
	_add_slider(_audio_tab, "Master", "audio/master", 0.0, 1.0, 0.01)
	_add_slider(_audio_tab, "Music", "audio/music", 0.0, 1.0, 0.01)
	_add_slider(_audio_tab, "SFX", "audio/sfx", 0.0, 1.0, 0.01)
	_add_slider(_audio_tab, "Voice", "audio/voice", 0.0, 1.0, 0.01)
	_add_slider(_audio_tab, "Ambience", "audio/ambience", 0.0, 1.0, 0.01)

func _build_gameplay() -> void:
	_add_slider(_gameplay_tab, "Camera sensitivity", "gameplay/camera_sensitivity", 0.05, 0.45, 0.01)
	_add_check(_gameplay_tab, "Invert Y", "gameplay/invert_y")
	_add_check(_gameplay_tab, "Vibration", "gameplay/vibration")
	_add_check(_gameplay_tab, "Subtitles", "gameplay/subtitles")
	_add_check(_gameplay_tab, "Show touch controls", "gameplay/show_touch_controls")
	_add_check(_gameplay_tab, "Reduce camera shake", "accessibility/reduce_camera_shake")

func _add_slider(parent: VBoxContainer, label_text: String, key: String, min_value: float, max_value: float, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 230
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(Settings.get_value(key, min_value))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 64
	value_label.text = "%.2f" % slider.value
	row.add_child(value_label)
	slider.value_changed.connect(_on_slider_changed.bind(key, value_label))

func _add_check(parent: VBoxContainer, label_text: String, key: String) -> void:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = bool(Settings.get_value(key, false))
	check.toggled.connect(_on_check_changed.bind(key))
	parent.add_child(check)

func _add_option(parent: VBoxContainer, label_text: String, key: String, options: Array) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 230
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current := Settings.get_value(key, options[0] if not options.is_empty() else null)
	for i in options.size():
		option.add_item(String(options[i]))
		option.set_item_metadata(i, options[i])
		if options[i] == current:
			option.select(i)
	option.item_selected.connect(_on_option_selected.bind(key, option))
	row.add_child(option)

func _on_slider_changed(value: float, key: String, value_label: Label) -> void:
	value_label.text = "%.2f" % value
	Settings.set_value(key, value)
	if key.begins_with("graphics/") and key != "graphics/preset":
		Settings.set_value("graphics/preset", "custom")

func _on_check_changed(value: bool, key: String) -> void:
	Settings.set_value(key, value)
	if key.begins_with("graphics/") and key != "graphics/preset":
		Settings.set_value("graphics/preset", "custom")

func _on_option_selected(index: int, key: String, option: OptionButton) -> void:
	var value: Variant = option.get_item_metadata(index)
	if key == "graphics/preset" and String(value) != "custom":
		Settings.apply_graphics_preset(String(value))
	else:
		Settings.set_value(key, value)
		if key.begins_with("graphics/") and key != "graphics/preset":
			Settings.set_value("graphics/preset", "custom")
