extends CharacterBody3D

@export var walk_speed := 5.0
@export var sprint_speed := 8.4
@export var crouch_speed := 2.8
@export var acceleration := 15.0
@export var air_control := 4.0
@export var jump_velocity := 8.5
@export var interaction_distance := 3.6

@onready var avatar: Node3D = $Avatar
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var _pitch := -0.16
var _yaw := 0.0
var _gravity := 24.0
var _mobile_controls: Control
var _mobile_crouch := false
var _current_interactable: InteractionPoint

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
	camera.make_current()
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	call_deferred("_resolve_mobile_controls")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		var sensitivity := float(Settings.get_value("gameplay/camera_sensitivity", 0.18)) * 0.01
		_apply_look(event.relative * sensitivity)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact"):
		_interact()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := Input.is_action_pressed("sprint")
	var jump_requested := Input.is_action_just_pressed("jump")
	var crouching := Input.is_action_pressed("crouch") or _mobile_crouch

	if is_instance_valid(_mobile_controls):
		input_vector += _mobile_controls.move_vector
		input_vector = input_vector.limit_length(1.0)
		sprinting = sprinting or _mobile_controls.is_sprinting()
		var mobile_look: Vector2 = _mobile_controls.consume_look_delta()
		if mobile_look != Vector2.ZERO:
			var mobile_sensitivity := float(Settings.get_value("gameplay/camera_sensitivity", 0.18)) * 0.92
			_apply_look(mobile_look * mobile_sensitivity)
		if _mobile_controls.consume_interact():
			_interact()
		if _mobile_controls.consume_jump():
			jump_requested = true
		if _mobile_controls.consume_crouch_toggle():
			_mobile_crouch = not _mobile_crouch
			crouching = _mobile_crouch

	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var desired_direction := (right * input_vector.x + forward * -input_vector.y).normalized()
	var target_speed := crouch_speed if crouching else (sprint_speed if sprinting else walk_speed)
	var target_velocity := desired_direction * target_speed
	var accel := acceleration if is_on_floor() else air_control

	velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif jump_requested and not crouching:
		velocity.y = jump_velocity

	move_and_slide()
	_update_crouch(crouching, delta)
	_update_camera(sprinting, crouching, delta)

	if desired_direction.length_squared() > 0.05:
		var target_yaw := atan2(desired_direction.x, desired_direction.z)
		avatar.rotation.y = lerp_angle(avatar.rotation.y, target_yaw, 1.0 - exp(-12.0 * delta))

	if avatar.has_method("set_motion_state"):
		avatar.call("set_motion_state", Vector2(velocity.x, velocity.z).length(), sprinting, crouching, delta)

	_update_interaction_prompt()

func _update_crouch(crouching: bool, delta: float) -> void:
	var capsule := body_collision.shape as CapsuleShape3D
	if capsule == null:
		return
	var target_height := 1.28 if crouching else 1.72
	var target_y := 0.68 if crouching else 0.90
	var blend := 1.0 - exp(-12.0 * delta)
	capsule.height = lerpf(capsule.height, target_height, blend)
	body_collision.position.y = lerpf(body_collision.position.y, target_y, blend)

func _update_camera(sprinting: bool, crouching: bool, delta: float) -> void:
	var pivot_target := 1.28 if crouching else 1.55
	camera_pivot.position.y = lerpf(camera_pivot.position.y, pivot_target, 1.0 - exp(-9.0 * delta))
	var moving_fast := sprinting and Vector2(velocity.x, velocity.z).length() > walk_speed
	var target_fov := 77.0 if moving_fast else 72.0
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-6.0 * delta))

func _apply_look(delta: Vector2) -> void:
	var invert := -1.0 if bool(Settings.get_value("gameplay/invert_y", false)) else 1.0
	_yaw -= delta.x
	_pitch -= delta.y * invert
	_pitch = clampf(_pitch, -0.92, 0.48)
	camera_pivot.rotation.y = _yaw
	spring_arm.rotation.x = _pitch

func _update_interaction_prompt() -> void:
	var nearest: InteractionPoint = null
	var nearest_distance := interaction_distance
	for node in get_tree().get_nodes_in_group("interactables"):
		if not (node is InteractionPoint):
			continue
		var point := node as InteractionPoint
		if not point.enabled:
			continue
		var distance := global_position.distance_to(point.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = point

	if nearest != _current_interactable:
		_current_interactable = nearest
		if is_instance_valid(nearest):
			EventBus.interaction_prompt_changed.emit(nearest.prompt, true)
		else:
			EventBus.interaction_prompt_changed.emit("", false)

func _interact() -> void:
	if is_instance_valid(_current_interactable):
		_current_interactable.interact(self)

func _resolve_mobile_controls() -> void:
	var nodes := get_tree().get_nodes_in_group("mobile_controls")
	if not nodes.is_empty():
		_mobile_controls = nodes[0]
