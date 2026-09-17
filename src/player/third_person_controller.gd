extends CharacterBody3D

@export var walk_speed := 5.0
@export var sprint_speed := 8.4
@export var crouch_speed := 2.8
@export var acceleration := 18.0
@export var ground_friction := 24.0
@export var air_control := 4.5
@export var jump_velocity := 8.5
@export var interaction_distance := 4.2
@export var interaction_cone_dot := 0.72
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.14

@onready var avatar: Node3D = $Avatar
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var _pitch := -0.16
var _yaw := 0.0
var _gravity := 24.0
var _mobile_controls: MobileControls
var _mobile_crouch := false
var _current_interactable: InteractionPoint
var _active_vehicle: DriveableVehicle
var _coyote_remaining := 0.0
var _jump_buffer_remaining := 0.0
var _interaction_refresh := 0.0

func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 24.0))
	camera.make_current()
	floor_snap_length = 0.24
	floor_stop_on_slope = true
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
	_update_mobile_look()
	if is_instance_valid(_active_vehicle):
		_process_vehicle(delta)
	else:
		_process_on_foot(delta)

func _process_on_foot(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := Input.is_action_pressed("sprint")
	var crouching := Input.is_action_pressed("crouch") or _mobile_crouch
	var jump_requested := Input.is_action_just_pressed("jump")

	if is_instance_valid(_mobile_controls):
		input_vector += _mobile_controls.move_vector
		input_vector = input_vector.limit_length(1.0)
		sprinting = sprinting or _mobile_controls.is_sprinting()
		if _mobile_controls.consume_interact():
			_interact()
		if _mobile_controls.consume_jump():
			jump_requested = true
		if _mobile_controls.consume_crouch_toggle():
			_mobile_crouch = not _mobile_crouch
			crouching = _mobile_crouch

	if jump_requested:
		_jump_buffer_remaining = jump_buffer_time
	else:
		_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)

	if is_on_floor():
		_coyote_remaining = coyote_time
	else:
		_coyote_remaining = maxf(0.0, _coyote_remaining - delta)

	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var desired_direction := right * input_vector.x + forward * -input_vector.y
	if desired_direction.length_squared() > 1.0:
		desired_direction = desired_direction.normalized()
	var has_move_input := desired_direction.length_squared() > 0.0025
	var target_speed := crouch_speed if crouching else (sprint_speed if sprinting else walk_speed)
	var target_velocity := desired_direction * target_speed

	if has_move_input:
		var accel := acceleration if is_on_floor() else air_control
		velocity.x = move_toward(velocity.x, target_velocity.x, accel * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, accel * delta)
	else:
		var decel := ground_friction if is_on_floor() else air_control * 0.22
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.6

	if _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0 and not crouching:
		velocity.y = jump_velocity
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0

	move_and_slide()
	_update_crouch(crouching, delta)
	_update_camera(false, sprinting, crouching, delta)

	if has_move_input:
		var target_yaw := atan2(desired_direction.x, desired_direction.z)
		avatar.rotation.y = lerp_angle(avatar.rotation.y, target_yaw, 1.0 - exp(-13.0 * delta))

	if avatar.has_method("set_motion_state"):
		avatar.call("set_motion_state", Vector2(velocity.x, velocity.z).length(), sprinting, crouching, delta)

	_interaction_refresh -= delta
	if _interaction_refresh <= 0.0:
		_interaction_refresh = 0.045
		_update_interaction_prompt()

func _process_vehicle(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var braking := Input.is_action_pressed("crouch")
	var handbrake := Input.is_action_pressed("jump")
	var exit_requested := Input.is_action_just_pressed("interact")

	if is_instance_valid(_mobile_controls):
		input_vector += _mobile_controls.move_vector
		input_vector = input_vector.limit_length(1.0)
		braking = braking or _mobile_controls.is_vehicle_braking()
		handbrake = handbrake or _mobile_controls.is_handbrake_pressed()
		if _mobile_controls.consume_interact():
			exit_requested = true

	var throttle := clampf(-input_vector.y, -1.0, 1.0)
	var steer_value := clampf(input_vector.x, -1.0, 1.0)
	_active_vehicle.apply_driver_input(throttle, steer_value, 1.0 if braking else 0.0, 1.0 if handbrake else 0.0, delta)

	global_position = _active_vehicle.get_driver_anchor_global_position()
	velocity = Vector3.ZERO
	_update_camera(true, false, false, delta)

	if exit_requested:
		if _active_vehicle.get_speed_kph() < 7.0:
			_exit_vehicle()
		else:
			EventBus.show_toast("Slow down before leaving the vehicle.", 1.4)

func _update_mobile_look() -> void:
	if not is_instance_valid(_mobile_controls):
		return
	var mobile_look := _mobile_controls.consume_look_delta()
	if mobile_look != Vector2.ZERO:
		var mobile_sensitivity := float(Settings.get_value("gameplay/camera_sensitivity", 0.18)) * 0.92
		_apply_look(mobile_look * mobile_sensitivity)

func _update_crouch(crouching: bool, delta: float) -> void:
	var capsule := body_collision.shape as CapsuleShape3D
	if capsule == null:
		return
	var target_height := 1.28 if crouching else 1.72
	var target_y := 0.68 if crouching else 0.90
	var blend := 1.0 - exp(-12.0 * delta)
	capsule.height = lerpf(capsule.height, target_height, blend)
	body_collision.position.y = lerpf(body_collision.position.y, target_y, blend)

func _update_camera(in_vehicle: bool, sprinting: bool, crouching: bool, delta: float) -> void:
	var pivot_target := 1.46 if in_vehicle else (1.28 if crouching else 1.55)
	camera_pivot.position.y = lerpf(camera_pivot.position.y, pivot_target, 1.0 - exp(-9.0 * delta))
	var speed_2d := Vector2(velocity.x, velocity.z).length()
	var moving_fast := sprinting and speed_2d > walk_speed
	var target_fov := 76.0 if in_vehicle else (77.0 if moving_fast else 72.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-6.0 * delta))
	var target_arm := 5.15 if in_vehicle else 3.78
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_arm, 1.0 - exp(-7.5 * delta))
	var target_offset_x := 0.12 if in_vehicle else 0.34
	camera.position.x = lerpf(camera.position.x, target_offset_x, 1.0 - exp(-8.0 * delta))

func _apply_look(delta: Vector2) -> void:
	var invert := -1.0 if bool(Settings.get_value("gameplay/invert_y", false)) else 1.0
	_yaw -= delta.x
	_pitch -= delta.y * invert
	_pitch = clampf(_pitch, -0.92, 0.48)
	camera_pivot.rotation.y = _yaw
	spring_arm.rotation.x = _pitch

func _update_interaction_prompt() -> void:
	if is_instance_valid(_active_vehicle):
		_set_current_interactable(null)
		return

	var nearest: InteractionPoint = null
	var best_score := -INF
	var camera_origin := camera.global_position
	var camera_forward := -camera.global_transform.basis.z
	var space_state := get_world_3d().direct_space_state

	for node in get_tree().get_nodes_in_group("interactables"):
		if not (node is InteractionPoint):
			continue
		var point := node as InteractionPoint
		if not point.enabled:
			continue
		var to_point := point.global_position - camera_origin
		var distance := to_point.length()
		if distance <= 0.05 or distance > interaction_distance:
			continue
		var direction := to_point / distance
		var facing := camera_forward.dot(direction)
		if facing < interaction_cone_dot:
			continue
		if not _has_line_of_sight(space_state, camera_origin, point.global_position, distance):
			continue
		var score := facing * 4.0 - distance * 0.16
		if score > best_score:
			best_score = score
			nearest = point

	_set_current_interactable(nearest)

func _has_line_of_sight(space_state: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, target_distance: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var hit_position: Vector3 = hit.get("position", to)
	return from.distance_to(hit_position) >= target_distance - 0.32

func _set_current_interactable(next: InteractionPoint) -> void:
	if next == _current_interactable:
		return
	_current_interactable = next
	if is_instance_valid(next):
		EventBus.interaction_prompt_changed.emit(next.prompt, true)
	else:
		EventBus.interaction_prompt_changed.emit("", false)

func _interact() -> void:
	if is_instance_valid(_active_vehicle):
		if _active_vehicle.get_speed_kph() < 7.0:
			_exit_vehicle()
		else:
			EventBus.show_toast("Slow down before leaving the vehicle.", 1.4)
		return
	if not is_instance_valid(_current_interactable):
		return

	if _current_interactable.action_id == "vehicle_enter":
		var path_text := String(_current_interactable.metadata.get("vehicle_path", ""))
		if not path_text.is_empty():
			var vehicle_node := get_node_or_null(NodePath(path_text))
			if vehicle_node is DriveableVehicle:
				_current_interactable.interact(self)
				_enter_vehicle(vehicle_node as DriveableVehicle)
				return
	_current_interactable.interact(self)

func _enter_vehicle(vehicle: DriveableVehicle) -> void:
	if not is_instance_valid(vehicle):
		return
	_active_vehicle = vehicle
	vehicle.set_driver(self)
	avatar.visible = false
	body_collision.set_deferred("disabled", true)
	_mobile_crouch = false
	velocity = Vector3.ZERO
	_set_current_interactable(null)
	if is_instance_valid(_mobile_controls):
		_mobile_controls.set_vehicle_mode(true)
	EventBus.show_toast("Vehicle controls active", 1.2)

func _exit_vehicle() -> void:
	if not is_instance_valid(_active_vehicle):
		return
	var vehicle := _active_vehicle
	var exit_position := vehicle.get_exit_position()
	vehicle.clear_driver()
	_active_vehicle = null
	global_position = exit_position
	velocity = Vector3.ZERO
	avatar.visible = true
	body_collision.set_deferred("disabled", false)
	if is_instance_valid(_mobile_controls):
		_mobile_controls.set_vehicle_mode(false)
	EventBus.show_toast("Exited vehicle", 1.0)

func get_vehicle_hud_state() -> Dictionary:
	if not is_instance_valid(_active_vehicle):
		return {}
	return _active_vehicle.get_vehicle_stats()

func is_driving() -> bool:
	return is_instance_valid(_active_vehicle)

func _resolve_mobile_controls() -> void:
	var nodes := get_tree().get_nodes_in_group("mobile_controls")
	if nodes.is_empty():
		return
	var candidate := nodes[0]
	if candidate is MobileControls:
		_mobile_controls = candidate as MobileControls
		_mobile_controls.set_vehicle_mode(false)
