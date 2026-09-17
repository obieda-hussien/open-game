extends Control

const MOVE_RADIUS := 92.0
const LOOK_SCALE := 0.004
const ACTION_RADIUS := 58.0

var move_vector := Vector2.ZERO
var _look_delta := Vector2.ZERO
var _left_touch := -1
var _right_touch := -1
var _sprint_touch := -1
var _left_origin := Vector2.ZERO
var _left_position := Vector2.ZERO
var _interact_queued := false
var _sprint_pressed := false

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

func is_sprinting() -> bool:
	return _sprint_pressed

func _handle_touch(event: InputEventScreenTouch) -> void:
	var viewport_size := get_viewport_rect().size
	var use_center := _use_button_center(viewport_size)
	var sprint_center := _sprint_button_center(viewport_size)

	if event.pressed:
		if event.position.distance_to(use_center) <= ACTION_RADIUS:
			_interact_queued = true
			queue_redraw()
			return
		if event.position.distance_to(sprint_center) <= ACTION_RADIUS:
			_sprint_touch = event.index
			_sprint_pressed = true
			queue_redraw()
			return
		if event.position.x < viewport_size.x * 0.48 and event.position.y > viewport_size.y * 0.34 and _left_touch < 0:
			_left_touch = event.index
			_left_origin = event.position
			_left_position = event.position
			queue_redraw()
			return
		if _right_touch < 0:
			_right_touch = event.index
			return
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

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _left_touch:
		_left_position = event.position
		var offset := (_left_position - _left_origin) / MOVE_RADIUS
		move_vector = offset.limit_length(1.0)
		queue_redraw()
	elif event.index == _right_touch:
		_look_delta += event.relative * LOOK_SCALE

func _draw() -> void:
	if not visible:
		return
	var viewport_size := get_viewport_rect().size
	var base_color := Color(1, 1, 1, 0.16)
	var active_color := Color(0.22, 0.78, 1.0, 0.34)

	var fallback_left := Vector2(130.0, viewport_size.y - 135.0)
	var base := _left_origin if _left_touch >= 0 else fallback_left
	var knob := _left_position if _left_touch >= 0 else base
	draw_circle(base, MOVE_RADIUS, base_color)
	draw_circle(knob, 34.0, active_color)

	var use_center := _use_button_center(viewport_size)
	var sprint_center := _sprint_button_center(viewport_size)
	draw_circle(use_center, ACTION_RADIUS, Color(1.0, 0.42, 0.20, 0.24))
	draw_circle(use_center, 22.0, Color(1.0, 0.64, 0.36, 0.52))
	draw_circle(
		sprint_center,
		ACTION_RADIUS,
		Color(0.22, 0.78, 1.0, 0.36 if _sprint_pressed else 0.18)
	)
	draw_circle(sprint_center, 18.0, Color(0.45, 0.86, 1.0, 0.48))

func _use_button_center(size: Vector2) -> Vector2:
	return Vector2(size.x - 105.0, size.y - 175.0)

func _sprint_button_center(size: Vector2) -> Vector2:
	return Vector2(size.x - 225.0, size.y - 92.0)

func _refresh_visibility() -> void:
	visible = OS.has_feature("mobile") or bool(Settings.get_value("gameplay/show_touch_controls", false))
	queue_redraw()

func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "gameplay/show_touch_controls":
		_refresh_visibility()
