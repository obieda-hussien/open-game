extends Control

const LOOK_SCALE := 0.0048

var move_vector := Vector2.ZERO
var _look_delta := Vector2.ZERO
var _left_touch := -1
var _right_touch := -1
var _sprint_touch := -1
var _brake_touch := -1
var _handbrake_touch := -1
var _left_position := Vector2.ZERO
var _interact_queued := false
var _jump_queued := false
var _crouch_toggle_queued := false
var _sprint_pressed := false
var _brake_pressed := false
var _handbrake_pressed := false
var _vehicle_mode := false

func _ready() -> void:
	add_to_group("mobile_controls")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	visibility_changed.connect(queue_redraw)
	EventBus.setting_changed.connect(_on_setting_changed)
	_refresh_visibility()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func set_vehicle_mode(enabled: bool) -> void:
	_vehicle_mode = enabled
	_sprint_pressed = false
	_brake_pressed = false
	_handbrake_pressed = false
	_sprint_touch = -1
	_brake_touch = -1
	_handbrake_touch = -1
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func consume_look_delta() -> Vector2:
	var value := _look_delta
	_look_delta = Vector2.ZERO
	return value

func consume_interact() -> bool:
	var value := _interact_queued
	_interact_queued = false
	return value

func consume_jump() -> bool:
	var value := _jump_queued
	_jump_queued = false
	return value

func consume_crouch_toggle() -> bool:
	var value := _crouch_toggle_queued
	_crouch_toggle_queued = false
	return value

func is_sprinting() -> bool:
	return _sprint_pressed

func is_vehicle_braking() -> bool:
	return _brake_pressed

func is_handbrake_pressed() -> bool:
	return _handbrake_pressed

func _handle_touch(event: InputEventScreenTouch) -> void:
	var size := get_viewport_rect().size
	var scale_value := _ui_scale(size)
	var button := _button_at(event.position, size, scale_value)

	if event.pressed:
		match button:
			"use":
				_interact_queued = true
				queue_redraw()
				return
			"jump":
				if _vehicle_mode:
					_handbrake_touch = event.index
					_handbrake_pressed = true
				else:
					_jump_queued = true
				queue_redraw()
				return
			"crouch":
				if _vehicle_mode:
					_brake_touch = event.index
					_brake_pressed = true
				else:
					_crouch_toggle_queued = true
				queue_redraw()
				return
			"sprint":
				_sprint_touch = event.index
				_sprint_pressed = true
				queue_redraw()
				return

		if event.position.x < size.x * 0.43 and event.position.y > size.y * 0.34 and _left_touch < 0:
			_left_touch = event.index
			_left_position = event.position
			_update_move_vector(size)
			queue_redraw()
			return
		if event.position.x > size.x * 0.36 and _right_touch < 0:
			_right_touch = event.index
	else:
		if event.index == _left_touch:
			_left_touch = -1
			move_vector = Vector2.ZERO
			queue_redraw()
		if event.index == _right_touch:
			_right_touch = -1
		if event.index == _sprint_touch:
			_sprint_touch = -1
			_sprint_pressed = false
			queue_redraw()
		if event.index == _brake_touch:
			_brake_touch = -1
			_brake_pressed = false
			queue_redraw()
		if event.index == _handbrake_touch:
			_handbrake_touch = -1
			_handbrake_pressed = false
			queue_redraw()

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _left_touch:
		_left_position = event.position
		_update_move_vector(get_viewport_rect().size)
		queue_redraw()
	elif event.index == _right_touch:
		_look_delta += event.relative * LOOK_SCALE

func _update_move_vector(size: Vector2) -> void:
	var scale_value := _ui_scale(size)
	var radius := 92.0 * scale_value
	var base := _joystick_center(size, scale_value)
	var offset := (_left_position - base) / radius
	move_vector = offset.limit_length(1.0)
	_left_position = base + move_vector * radius

func _draw() -> void:
	if not visible:
		return
	var size := get_viewport_rect().size
	var s := _ui_scale(size)
	var radius := 92.0 * s
	var base := _joystick_center(size, s)
	var knob := _left_position if _left_touch >= 0 else base

	draw_circle(base, radius, Color(0.02, 0.03, 0.04, 0.20))
	draw_arc(base, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.22), 2.0 * s)
	draw_circle(knob, 35.0 * s, Color(0.80, 0.88, 0.94, 0.30))
	draw_arc(knob, 35.0 * s, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.42), 2.0 * s)

	_draw_action_button(_button_center("use", size, s), 54.0 * s, "EXIT" if _vehicle_mode else "USE", Color(0.90, 0.42, 0.18, 0.30), s)
	_draw_action_button(_button_center("jump", size, s), 48.0 * s, "HANDBRAKE" if _vehicle_mode else "JUMP", Color(0.82, 0.86, 0.92, 0.25 if not _handbrake_pressed else 0.45), s)
	_draw_action_button(_button_center("crouch", size, s), 44.0 * s, "BRAKE" if _vehicle_mode else "CROUCH", Color(0.38, 0.54, 0.64, 0.25 if not _brake_pressed else 0.48), s)
	if not _vehicle_mode:
		_draw_action_button(_button_center("sprint", size, s), 45.0 * s, "RUN", Color(0.18, 0.68, 0.88, 0.42 if _sprint_pressed else 0.23), s)

func _draw_action_button(center: Vector2, radius: float, label: String, color: Color, s: float) -> void:
	draw_circle(center, radius, Color(0.01, 0.015, 0.02, 0.20))
	draw_circle(center, radius - 3.0 * s, color)
	draw_arc(center, radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.34), 1.8 * s)
	var font_size := maxi(9, roundi((11.0 if label.length() > 6 else 13.0) * s))
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius, 5.0 * s), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, Color(1.0, 1.0, 1.0, 0.88))

func _button_at(position: Vector2, size: Vector2, s: float) -> String:
	var actions := ["use", "jump", "crouch"] if _vehicle_mode else ["use", "jump", "crouch", "sprint"]
	for action in actions:
		var radius := 60.0 * s if action == "use" else 53.0 * s
		if position.distance_to(_button_center(action, size, s)) <= radius:
			return action
	return ""

func _button_center(action: String, size: Vector2, s: float) -> Vector2:
	var bottom := size.y - 34.0 * s
	match action:
		"use":
			return Vector2(size.x - 92.0 * s, bottom - 94.0 * s)
		"jump":
			return Vector2(size.x - 105.0 * s, bottom - 226.0 * s)
		"crouch":
			return Vector2(size.x - 220.0 * s, bottom - 70.0 * s)
		"sprint":
			return Vector2(size.x - 270.0 * s, bottom - 190.0 * s)
	return Vector2.ZERO

func _joystick_center(size: Vector2, s: float) -> Vector2:
	return Vector2(128.0 * s, size.y - 128.0 * s)

func _ui_scale(size: Vector2) -> float:
	return clampf(minf(size.x / 1280.0, size.y / 720.0), 0.72, 1.45)

func _refresh_visibility() -> void:
	visible = OS.has_feature("mobile") or bool(Settings.get_value("gameplay/show_touch_controls", false))
	queue_redraw()

func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "gameplay/show_touch_controls":
		_refresh_visibility()
