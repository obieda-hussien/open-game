class_name ProductionOriginRuntime
extends Node3D

const VEHICLE_SCENE_PATH := "res://scenes/vehicles/driveable_sedan.tscn"

var _source_scene: PackedScene
var _visual_root: Node3D
var _garage_door: AnimatableBody3D
var _garage_door_collision: CollisionShape3D
var _garage_interaction: InteractionPoint
var _street_lights: Array[OmniLight3D] = []
var _garage_light: OmniLight3D
var _garage_open := false

func configure(source: PackedScene) -> ProductionOriginRuntime:
	_source_scene = source
	name = "ProductionOrigin"
	return self

func _ready() -> void:
	_build_visuals()
	_build_collision_proxies()
	_build_garage_door()
	_build_interactions()
	_build_street_lighting()
	_spawn_driveable_vehicle()
	EventBus.world_action.connect(_on_world_action)

	_garage_open = bool(WorldState.get_flag("garage_opened", false))
	if _garage_open:
		_set_garage_door_immediate(true)

func _process(_delta: float) -> void:
	var hour := WorldState.get_hour_float()
	var night := hour >= 18.15 or hour < 6.0
	for light in _street_lights:
		light.visible = night
	if is_instance_valid(_garage_light):
		_garage_light.visible = night or _garage_open

func _build_visuals() -> void:
	if _source_scene == null:
		return
	var instance := _source_scene.instantiate()
	if not (instance is Node3D):
		instance.queue_free()
		return
	_visual_root = instance as Node3D
	_visual_root.name = "HiggsfieldCityBlock"
	add_child(_visual_root)
	_disable_embedded_cameras_and_lights(_visual_root)

func _build_collision_proxies() -> void:
	# The rendered GLB stays lightweight. Mobile collision uses deliberately simple
	# proxy volumes instead of triangle-mesh collision over the entire city block.
	_add_static_box("DistrictGround", Vector3(0, -0.30, 0), Vector3(94, 0.60, 94))

	# Garage shell around (-18, 0, -22), leaving a wide front opening.
	_add_static_box("GarageBack", Vector3(-18, 2.4, -29.0), Vector3(19.0, 4.8, 0.45))
	_add_static_box("GarageLeft", Vector3(-27.3, 2.4, -22.0), Vector3(0.45, 4.8, 14.0))
	_add_static_box("GarageRight", Vector3(-8.7, 2.4, -22.0), Vector3(0.45, 4.8, 14.0))
	_add_static_box("GarageFrontLeft", Vector3(-24.8, 2.4, -15.1), Vector3(5.0, 4.8, 0.42))
	_add_static_box("GarageFrontRight", Vector3(-11.2, 2.4, -15.1), Vector3(5.0, 4.8, 0.42))

	# Coarse building proxies. These are intentionally much cheaper than generating
	# convex collision for every imported mesh surface on Android.
	_add_static_box("ApartmentProxy", Vector3(22.0, 5.0, -24.0), Vector3(15.0, 10.0, 14.0))
	_add_static_box("CornerStoreProxy", Vector3(-24.0, 2.4, 20.0), Vector3(14.0, 4.8, 12.0))

func _build_garage_door() -> void:
	_garage_door = AnimatableBody3D.new()
	_garage_door.name = "PhysicalGarageDoor"
	_garage_door.position = Vector3(-18.0, 2.25, -15.0)
	add_child(_garage_door)

	var mesh_resource := BoxMesh.new()
	mesh_resource.size = Vector3(8.6, 4.35, 0.16)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_resource
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.14, 0.15)
	material.metallic = 0.42
	material.roughness = 0.48
	mesh.material_override = material
	_garage_door.add_child(mesh)

	var shape := BoxShape3D.new()
	shape.size = Vector3(8.6, 4.35, 0.20)
	_garage_door_collision = CollisionShape3D.new()
	_garage_door_collision.shape = shape
	_garage_door.add_child(_garage_door_collision)

func _build_interactions() -> void:
	_garage_interaction = _add_interaction("garage_open", "Open garage", Vector3(-18.0, 1.15, -12.9))
	_add_interaction("job_board", "Check job board", Vector3(-23.8, 1.45, -23.7))
	_add_interaction("delivery_pickup", "Collect package", Vector3(-13.4, 0.55, -18.2))
	_add_interaction("suspicious_car_inspect", "Inspect damaged car", Vector3(3.0, 0.72, -6.0))
	_create_package_visual(Vector3(-13.4, 0.34, -18.2))

func _build_street_lighting() -> void:
	var lamp_positions := [
		Vector3(-5.5, 5.2, -8.0),
		Vector3(11.0, 5.2, -7.0),
		Vector3(-8.0, 5.2, 11.0),
		Vector3(14.0, 5.2, 17.0)
	]
	for index in lamp_positions.size():
		var light := OmniLight3D.new()
		light.name = "StreetLamp_%02d" % index
		light.position = lamp_positions[index]
		light.light_color = Color(1.0, 0.68, 0.40)
		light.light_energy = 2.15
		light.omni_range = 12.5
		light.shadow_enabled = int(Settings.get_value("graphics/shadows", 1)) >= 2 and index < 2
		add_child(light)
		_street_lights.append(light)

	_garage_light = OmniLight3D.new()
	_garage_light.name = "GarageInteriorLight"
	_garage_light.position = Vector3(-18.0, 3.6, -22.0)
	_garage_light.light_color = Color(1.0, 0.74, 0.48)
	_garage_light.light_energy = 2.7
	_garage_light.omni_range = 11.0
	_garage_light.shadow_enabled = false
	add_child(_garage_light)

func _spawn_driveable_vehicle() -> void:
	if not ResourceLoader.exists(VEHICLE_SCENE_PATH):
		return
	var resource := ResourceLoader.load(VEHICLE_SCENE_PATH)
	if not (resource is PackedScene):
		return
	var vehicle := (resource as PackedScene).instantiate()
	if not (vehicle is Node3D):
		vehicle.queue_free()
		return
	vehicle.name = "PlayerSedan"
	vehicle.position = Vector3(8.0, 0.65, 12.0)
	vehicle.rotation.y = deg_to_rad(-18.0)
	add_child(vehicle)

func _on_world_action(action_id: String, _payload: Dictionary) -> void:
	if action_id == "garage_open" and not _garage_open:
		_open_garage_door()

func _open_garage_door() -> void:
	_garage_open = true
	if is_instance_valid(_garage_interaction):
		_garage_interaction.enabled = false
	if not is_instance_valid(_garage_door):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_garage_door, "position:y", 6.25, 1.25)
	tween.finished.connect(
		func() -> void:
			if is_instance_valid(_garage_door_collision):
				_garage_door_collision.set_deferred("disabled", true)
	)

func _set_garage_door_immediate(opened: bool) -> void:
	if not is_instance_valid(_garage_door):
		return
	_garage_door.position.y = 6.25 if opened else 2.25
	if is_instance_valid(_garage_door_collision):
		_garage_door_collision.disabled = opened
	if is_instance_valid(_garage_interaction):
		_garage_interaction.enabled = not opened

func _add_interaction(action_id: String, text: String, local_position: Vector3) -> InteractionPoint:
	var point := InteractionPoint.new().configure(action_id, text, {"production_origin": true})
	point.position = local_position
	add_child(point)
	return point

func _create_package_visual(local_position: Vector3) -> void:
	var mesh_resource := BoxMesh.new()
	mesh_resource.size = Vector3(0.68, 0.52, 0.55)
	var mesh := MeshInstance3D.new()
	mesh.name = "DeliveryPackage"
	mesh.mesh = mesh_resource
	mesh.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.22, 0.11)
	material.roughness = 0.94
	mesh.material_override = material
	add_child(mesh)

func _add_static_box(node_name: String, local_position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = local_position
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)

func _disable_embedded_cameras_and_lights(root: Node) -> void:
	if root is Camera3D:
		(root as Camera3D).current = false
	elif root is Light3D:
		(root as Light3D).visible = false
	for child in root.get_children():
		_disable_embedded_cameras_and_lights(child)
