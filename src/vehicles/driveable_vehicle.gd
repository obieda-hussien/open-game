class_name DriveableVehicle
extends VehicleBody3D

const MODEL_PATH := "res://assets/external/last_shift_driveable_sedan_v1.glb"

@export var max_engine_force := 1650.0
@export var max_brake_force := 31.0
@export var max_handbrake_force := 44.0
@export var max_forward_speed_kph := 145.0
@export var max_reverse_speed_kph := 34.0
@export var low_speed_steer_degrees := 34.0
@export var high_speed_steer_degrees := 10.5
@export var steering_response := 7.5
@export var fuel_capacity_liters := 46.0
@export var fuel_liters := 31.0
@export var idle_fuel_lph := 0.72
@export var peak_fuel_lph := 13.5

@onready var visual_root: Node3D = $VisualRoot
@onready var driver_anchor: Node3D = $DriverAnchor
@onready var exit_anchor: Node3D = $ExitAnchor
@onready var front_left: VehicleWheel3D = $WheelFrontLeft
@onready var front_right: VehicleWheel3D = $WheelFrontRight
@onready var rear_left: VehicleWheel3D = $WheelRearLeft
@onready var rear_right: VehicleWheel3D = $WheelRearRight

var driver: Node3D
var _interaction: InteractionPoint
var _throttle := 0.0
var _steer_input := 0.0
var _service_brake := 0.0
var _handbrake := 0.0
var _engine_running := true
var _visual_loaded := false

func _ready() -> void:
	add_to_group("driveable_vehicles")
	continuous_cd = true
	can_sleep = true
	_load_visual()
	_create_interaction()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(driver):
		_throttle = move_toward(_throttle, 0.0, delta * 4.0)
		_steer_input = move_toward(_steer_input, 0.0, delta * 4.0)
		_service_brake = maxf(_service_brake, 0.12 if linear_velocity.length() < 0.7 else 0.0)

	_apply_vehicle_controls(delta)
	_apply_drag()
	_consume_fuel(delta)

func set_driver(actor: Node3D) -> void:
	driver = actor
	sleeping = false
	if is_instance_valid(_interaction):
		_interaction.enabled = false

func clear_driver() -> void:
	driver = null
	_throttle = 0.0
	_steer_input = 0.0
	_service_brake = 0.25
	_handbrake = 0.0
	if is_instance_valid(_interaction):
		_interaction.enabled = true

func apply_driver_input(throttle: float, steer_value: float, braking: float, handbrake_value: float, _delta: float) -> void:
	_throttle = clampf(throttle, -1.0, 1.0)
	_steer_input = clampf(steer_value, -1.0, 1.0)
	_service_brake = clampf(braking, 0.0, 1.0)
	_handbrake = clampf(handbrake_value, 0.0, 1.0)

func get_driver_anchor_global_position() -> Vector3:
	return driver_anchor.global_position

func get_exit_position() -> Vector3:
	return exit_anchor.global_position + Vector3.UP * 0.12

func get_speed_kph() -> float:
	return linear_velocity.length() * 3.6

func get_vehicle_stats() -> Dictionary:
	return {
		"speed_kph": get_speed_kph(),
		"fuel_liters": fuel_liters,
		"fuel_percent": fuel_liters / maxf(fuel_capacity_liters, 0.001),
		"engine_running": _engine_running,
		"traction": _minimum_skid_info()
	}

func _apply_vehicle_controls(delta: float) -> void:
	var speed_kph := get_speed_kph()
	var speed_ratio := clampf(speed_kph / maxf(max_forward_speed_kph, 1.0), 0.0, 1.0)
	var steer_limit := deg_to_rad(lerpf(low_speed_steer_degrees, high_speed_steer_degrees, pow(speed_ratio, 0.62)))
	var target_steer := _steer_input * steer_limit
	steering = lerp_angle(steering, target_steer, 1.0 - exp(-steering_response * delta))

	var skid := _minimum_skid_info()
	var torque_factor := 1.0 - 0.72 * pow(speed_ratio, 1.55)
	var force := _throttle * max_engine_force * maxf(torque_factor, 0.22)

	if _throttle < 0.0:
		var reverse_ratio := clampf(speed_kph / maxf(max_reverse_speed_kph, 1.0), 0.0, 1.0)
		force *= 0.58 * (1.0 - reverse_ratio)
	elif speed_kph >= max_forward_speed_kph:
		force = minf(force, 0.0)

	# Lightweight traction control: reduce torque when driven wheels lose grip.
	if skid < 0.72 and absf(force) > 0.01:
		force *= clampf(remap(skid, 0.15, 0.72, 0.18, 1.0), 0.18, 1.0)

	if not _engine_running or fuel_liters <= 0.001:
		force = 0.0
	engine_force = force

	var service := _service_brake * max_brake_force
	# Crude ABS approximation. VehicleWheel3D exposes skid information, so avoid
	# locking every wheel at full pressure when grip has already collapsed.
	if service > 0.0 and skid < 0.42:
		service *= 0.58
	brake = service

	front_left.brake = service
	front_right.brake = service
	rear_left.brake = service + _handbrake * max_handbrake_force
	rear_right.brake = service + _handbrake * max_handbrake_force

func _minimum_skid_info() -> float:
	var skid := 1.0
	var contacted := false
	for wheel in [front_left, front_right, rear_left, rear_right]:
		if wheel.is_in_contact():
			contacted = true
			skid = minf(skid, wheel.get_skidinfo())
	return skid if contacted else 1.0

func _apply_drag() -> void:
	var speed := linear_velocity.length()
	if speed < 0.05:
		return
	# Quadratic aero drag plus a small rolling term. Forces remain intentionally
	# modest so the raycast suspension owns the contact feel.
	var aero := -linear_velocity.normalized() * speed * speed * 0.52
	var rolling := -linear_velocity * 7.5
	apply_central_force(aero + rolling)

func _consume_fuel(delta: float) -> void:
	if not _engine_running or fuel_liters <= 0.0:
		fuel_liters = maxf(fuel_liters, 0.0)
		return
	var load := clampf(absf(engine_force) / maxf(max_engine_force, 1.0), 0.0, 1.0)
	var liters_per_hour := lerpf(idle_fuel_lph, peak_fuel_lph, pow(load, 0.72))
	fuel_liters = maxf(0.0, fuel_liters - liters_per_hour * delta / 3600.0)
	if fuel_liters <= 0.001:
		_engine_running = false

func _load_visual() -> void:
	if not ResourceLoader.exists(MODEL_PATH):
		_create_fallback_visual()
		return
	var resource := ResourceLoader.load(MODEL_PATH)
	if not (resource is PackedScene):
		_create_fallback_visual()
		return
	var model := (resource as PackedScene).instantiate()
	if not (model is Node3D):
		model.queue_free()
		_create_fallback_visual()
		return
	model.name = "ProductionSedanModel"
	visual_root.add_child(model)
	_disable_embedded_cameras_and_lights(model)
	_visual_loaded = true

func _create_fallback_visual() -> void:
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.72, 0.72, 4.15)
	var body := MeshInstance3D.new()
	body.name = "FallbackCarBody"
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.73, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.17, 0.18, 0.20)
	material.metallic = 0.34
	material.roughness = 0.42
	body.material_override = material
	visual_root.add_child(body)

func _create_interaction() -> void:
	_interaction = InteractionPoint.new().configure(
		"vehicle_enter",
		"Drive sedan",
		{"vehicle_path": String(get_path())}
	)
	_interaction.name = "VehicleInteraction"
	_interaction.position = Vector3(1.12, 0.92, 0.05)
	add_child(_interaction)

func _disable_embedded_cameras_and_lights(root: Node) -> void:
	if root is Camera3D:
		(root as Camera3D).current = false
	elif root is Light3D:
		(root as Light3D).visible = false
	for child in root.get_children():
		_disable_embedded_cameras_and_lights(child)
