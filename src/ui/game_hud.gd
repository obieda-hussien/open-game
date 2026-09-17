extends Control

var _objective_label: Label
var _status_label: Label
var _prompt_label: Label
var _toast_label: Label
var _toast_time := 0.0
var _choices_box: VBoxContainer
var _settings: SettingsMenu
var _last_perf_scale := 1.0
var _last_perf_pressure := 0.0
var _player: Node
var _vehicle_panel: PanelContainer
var _speed_label: Label
var _fuel_label: Label
var _interaction_visible := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.toast.connect(_on_toast)
	EventBus.mission_updated.connect(_on_mission_updated)
	EventBus.mission_choices_requested.connect(_on_choices_requested)
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.performance_changed.connect(_on_performance_changed)
	EventBus.dynamic_event_started.connect(_on_dynamic_event)
	_objective_label.text = MissionManager.get_primary_objective()
	call_deferred("_resolve_player")

func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast_label.visible = false

	_status_label.text = "DAY %d  •  %s  •  $%d  •  REP %d\n%d FPS  ·  %d%% RES" % [
		WorldState.day,
		WorldState.get_clock_text(),
		WorldState.cash,
		WorldState.reputation,
		Engine.get_frames_per_second(),
		roundi(_last_perf_scale * 100.0)
	]
	_update_vehicle_hud()

func _draw() -> void:
	if not _interaction_visible:
		return
	var center := get_viewport_rect().size * 0.5
	var color := Color(1.0, 1.0, 1.0, 0.86)
	draw_circle(center, 2.4, color)
	draw_arc(center, 9.5, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.46), 1.2)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_settings()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var settings_button := Button.new()
	settings_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	settings_button.offset_left = 16.0
	settings_button.offset_right = 88.0
	settings_button.offset_top = 14.0
	settings_button.offset_bottom = 50.0
	settings_button.text = "MENU"
	settings_button.add_theme_font_size_override("font_size", 12)
	settings_button.add_theme_stylebox_override("normal", _panel_style(Color(0.015, 0.020, 0.027, 0.62), 10.0))
	settings_button.add_theme_stylebox_override("hover", _panel_style(Color(0.05, 0.07, 0.09, 0.78), 10.0))
	settings_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.08, 0.10, 0.12, 0.88), 10.0))
	settings_button.pressed.connect(_toggle_settings)
	add_child(settings_button)

	var status_panel := PanelContainer.new()
	status_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_panel.offset_left = -248.0
	status_panel.offset_right = -14.0
	status_panel.offset_top = 14.0
	status_panel.offset_bottom = 75.0
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.018, 0.024, 0.58), 12.0))
	add_child(status_panel)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.97, 0.91))
	_status_label.add_theme_constant_override("line_spacing", 1)
	status_panel.add_child(_status_label)

	var objective_panel := PanelContainer.new()
	objective_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_panel.offset_left = -248.0
	objective_panel.offset_right = 248.0
	objective_panel.offset_top = 14.0
	objective_panel.offset_bottom = 56.0
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.018, 0.024, 0.52), 12.0))
	add_child(objective_panel)

	_objective_label = Label.new()
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_objective_label.add_theme_font_size_override("font_size", 14)
	_objective_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92, 0.93))
	objective_panel.add_child(_objective_label)

	_prompt_label = Label.new()
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.offset_left = -220.0
	_prompt_label.offset_right = 220.0
	_prompt_label.offset_top = -92.0
	_prompt_label.offset_bottom = -60.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.94, 0.94))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	_prompt_label.visible = false
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_label)

	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -245.0
	_toast_label.offset_right = 245.0
	_toast_label.offset_top = 70.0
	_toast_label.offset_bottom = 105.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_toast_label.add_theme_constant_override("shadow_offset_x", 1)
	_toast_label.add_theme_constant_override("shadow_offset_y", 2)
	_toast_label.visible = false
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_label)

	_build_vehicle_panel()

	_choices_box = VBoxContainer.new()
	_choices_box.set_anchors_preset(Control.PRESET_CENTER)
	_choices_box.offset_left = -250.0
	_choices_box.offset_right = 250.0
	_choices_box.offset_top = -72.0
	_choices_box.offset_bottom = 176.0
	_choices_box.add_theme_constant_override("separation", 9)
	add_child(_choices_box)

	_settings = SettingsMenu.new()
	add_child(_settings)

func _build_vehicle_panel() -> void:
	_vehicle_panel = PanelContainer.new()
	_vehicle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_vehicle_panel.offset_left = -108.0
	_vehicle_panel.offset_right = 108.0
	_vehicle_panel.offset_top = -88.0
	_vehicle_panel.offset_bottom = -18.0
	_vehicle_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.010, 0.016, 0.022, 0.66), 15.0))
	_vehicle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vehicle_panel.visible = false
	add_child(_vehicle_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_vehicle_panel.add_child(row)

	_speed_label = Label.new()
	_speed_label.custom_minimum_size = Vector2(112, 52)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speed_label.add_theme_font_size_override("font_size", 22)
	_speed_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	row.add_child(_speed_label)

	_fuel_label = Label.new()
	_fuel_label.custom_minimum_size = Vector2(74, 52)
	_fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fuel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fuel_label.add_theme_font_size_override("font_size", 12)
	_fuel_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.91))
	row.add_child(_fuel_label)

func _update_vehicle_hud() -> void:
	if not is_instance_valid(_player) or not _player.has_method("get_vehicle_hud_state"):
		_vehicle_panel.visible = false
		return
	var state: Dictionary = _player.call("get_vehicle_hud_state")
	if state.is_empty():
		_vehicle_panel.visible = false
		return
	_vehicle_panel.visible = true
	var speed := int(round(float(state.get("speed_kph", 0.0))))
	var fuel_percent := int(round(float(state.get("fuel_percent", 0.0)) * 100.0))
	_speed_label.text = "%03d\nkm/h" % speed
	_fuel_label.text = "FUEL\n%d%%" % fuel_percent

func _panel_style(color: Color, radius: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.content_margin_left = 11.0
	style.content_margin_right = 11.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style

func _resolve_player() -> void:
	_player = get_node_or_null("../../Player")

func _toggle_settings() -> void:
	if _settings.visible:
		_settings.close()
	else:
		_settings.open()

func _on_prompt_changed(prompt: String, shown: bool) -> void:
	_prompt_label.text = ("TAP USE  •  %s" if OS.has_feature("mobile") else "[E]  %s") % prompt
	_prompt_label.visible = shown
	_interaction_visible = shown
	queue_redraw()

func _on_toast(text: String, duration: float) -> void:
	_toast_label.text = text
	_toast_label.visible = true
	_toast_time = duration

func _on_mission_updated(_mission_id: String, objective: String) -> void:
	_objective_label.text = objective

func _on_mission_completed(_mission_id: String) -> void:
	_objective_label.text = MissionManager.get_primary_objective()
	_clear_choices()

func _on_choices_requested(mission_id: String, choices: Array) -> void:
	_clear_choices()
	for raw_choice in choices:
		if not (raw_choice is Dictionary):
			continue
		var choice: Dictionary = raw_choice
		var button := Button.new()
		button.text = String(choice.get("label", choice.get("id", "Choose")))
		button.custom_minimum_size.y = 50
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_stylebox_override("normal", _panel_style(Color(0.025, 0.035, 0.045, 0.92), 11.0))
		button.pressed.connect(
			func() -> void:
				MissionManager.choose(mission_id, String(choice.get("id", "")))
				_clear_choices()
		)
		_choices_box.add_child(button)

func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()

func _on_performance_changed(render_scale: float, pressure: float, _tier: String) -> void:
	_last_perf_scale = render_scale
	_last_perf_pressure = pressure

func _on_dynamic_event(_event_id: String, title: String, description: String) -> void:
	_on_toast("%s — %s" % [title, description], 4.0)
