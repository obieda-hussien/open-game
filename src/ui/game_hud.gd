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
	_status_label.text = "DAY %d   %s   $%d   REP %d\n%d FPS  %.0f%% scale" % [
		WorldState.day,
		WorldState.get_clock_text(),
		WorldState.cash,
		WorldState.reputation,
		Engine.get_frames_per_second(),
		_last_perf_scale * 100.0
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _settings.visible:
			_settings.close()
		else:
			_settings.open()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 20
	top.offset_bottom = 118
	add_child(top)

	var top_row := HBoxContainer.new()
	top.add_child(top_row)
	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 15)
	top_row.add_child(_status_label)
	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.pressed.connect(func() -> void: _settings.open())
	top_row.add_child(settings_button)

	_objective_label = Label.new()
	_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective_label.offset_left = 24
	_objective_label.offset_right = -24
	_objective_label.offset_top = 102
	_objective_label.offset_bottom = 152
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 20)
	add_child(_objective_label)

	_prompt_label = Label.new()
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.offset_left = -260
	_prompt_label.offset_right = 260
	_prompt_label.offset_top = -100
	_prompt_label.offset_bottom = -50
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 19)
	_prompt_label.visible = false
	add_child(_prompt_label)

	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -260
	_toast_label.offset_right = 260
	_toast_label.offset_top = 156
	_toast_label.offset_bottom = 204
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.visible = false
	add_child(_toast_label)

	_choices_box = VBoxContainer.new()
	_choices_box.set_anchors_preset(Control.PRESET_CENTER)
	_choices_box.offset_left = -300
	_choices_box.offset_right = 300
	_choices_box.offset_top = -90
	_choices_box.offset_bottom = 160
	_choices_box.add_theme_constant_override("separation", 10)
	add_child(_choices_box)

	_settings = SettingsMenu.new()
	add_child(_settings)

func _on_prompt_changed(prompt: String, shown: bool) -> void:
	_prompt_label.text = "[E / USE] %s" % prompt
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
		button.custom_minimum_size.y = 48
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
