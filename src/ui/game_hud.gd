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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	EventBus.interaction_prompt_changed.connect(_on_prompt_changed)
	EventBus.toast.connect(_on_toast)
	EventBus.mission_updated.connect(_on_mission_updated)
	EventBus.mission_choices_requested.connect(_on_choices_requested)
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.performance_changed.connect(_on_performance_changed)
	EventBus.dynamic_event_started.connect(_on_dynamic_event)
	_objective_label.text = MissionManager.get_primary_objective()

func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0:
			_toast_label.visible = false
	_status_label.text = "DAY %d  %s   $%d   REP %d\n%d FPS   %d%%" % [
		WorldState.day,
		WorldState.get_clock_text(),
		WorldState.cash,
		WorldState.reputation,
		Engine.get_frames_per_second(),
		roundi(_last_perf_scale * 100.0)
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_settings()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var status_panel := ColorRect.new()
	status_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	status_panel.offset_left = 18.0
	status_panel.offset_top = 16.0
	status_panel.offset_right = 292.0
	status_panel.offset_bottom = 84.0
	status_panel.color = Color(0.018, 0.025, 0.032, 0.64)
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_panel)

	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status_label.offset_left = 30.0
	_status_label.offset_top = 24.0
	_status_label.offset_right = 282.0
	_status_label.offset_bottom = 78.0
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_label)

	var settings_button := Button.new()
	settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -102.0
	settings_button.offset_right = -18.0
	settings_button.offset_top = 16.0
	settings_button.offset_bottom = 58.0
	settings_button.text = "MENU"
	settings_button.add_theme_font_size_override("font_size", 13)
	settings_button.pressed.connect(_toggle_settings)
	add_child(settings_button)

	var objective_panel := ColorRect.new()
	objective_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_panel.offset_left = -280.0
	objective_panel.offset_right = 280.0
	objective_panel.offset_top = 18.0
	objective_panel.offset_bottom = 66.0
	objective_panel.color = Color(0.018, 0.025, 0.032, 0.56)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(objective_panel)

	_objective_label = Label.new()
	_objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_label.offset_left = -265.0
	_objective_label.offset_right = 265.0
	_objective_label.offset_top = 28.0
	_objective_label.offset_bottom = 60.0
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_objective_label.add_theme_font_size_override("font_size", 16)
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_label)

	_prompt_label = Label.new()
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.offset_left = -265.0
	_prompt_label.offset_right = 265.0
	_prompt_label.offset_top = -94.0
	_prompt_label.offset_bottom = -58.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 17)
	_prompt_label.visible = false
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_label)

	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -285.0
	_toast_label.offset_right = 285.0
	_toast_label.offset_top = 82.0
	_toast_label.offset_bottom = 122.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.visible = false
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_label)

	_choices_box = VBoxContainer.new()
	_choices_box.set_anchors_preset(Control.PRESET_CENTER)
	_choices_box.offset_left = -275.0
	_choices_box.offset_right = 275.0
	_choices_box.offset_top = -70.0
	_choices_box.offset_bottom = 170.0
	_choices_box.add_theme_constant_override("separation", 10)
	add_child(_choices_box)

	_settings = SettingsMenu.new()
	add_child(_settings)

func _toggle_settings() -> void:
	if _settings.visible:
		_settings.close()
	else:
		_settings.open()

func _on_prompt_changed(prompt: String, shown: bool) -> void:
	_prompt_label.text = ("USE  •  %s" if OS.has_feature("mobile") else "[E / USE] %s") % prompt
	_prompt_label.visible = shown

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
		button.custom_minimum_size.y = 52
		button.add_theme_font_size_override("font_size", 16)
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
