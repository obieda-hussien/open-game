class_name WorldCell
extends Node3D

var cell_coord := Vector2i.ZERO
var cell_size := 96.0
var detail_scale := 1.0
var _rng := RandomNumberGenerator.new()

var _mat_asphalt: StandardMaterial3D
var _mat_dirt: StandardMaterial3D
var _mat_concrete: StandardMaterial3D
var _mat_plaster_a: StandardMaterial3D
var _mat_plaster_b: StandardMaterial3D
var _mat_brick: StandardMaterial3D
var _mat_roof: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_glass: StandardMaterial3D
var _mat_grass: StandardMaterial3D
var _mat_wood: StandardMaterial3D
var _mat_marker: StandardMaterial3D

func configure(coord: Vector2i, size: float, detail: float = 1.0) -> WorldCell:
	cell_coord = coord
	cell_size = size
	detail_scale = detail
	name = "Cell_%d_%d" % [coord.x, coord.y]
	position = Vector3(float(coord.x) * cell_size, 0.0, float(coord.y) * cell_size)
	_rng.seed = abs(hash("%d:%d" % [coord.x, coord.y]))
	_build()
	return self

func _build() -> void:
	_make_materials()
	_add_ground_and_roads()
	_add_city_blocks()
	_add_grass_clusters()
	if detail_scale >= 0.64:
		_add_roadside_props()
	if cell_coord == Vector2i.ZERO:
		_add_origin_landmarks()
	elif detail_scale >= 0.78 and _rng.randf() < 0.70:
		_add_parked_car(Vector3(7.4, 0.0, _rng.randf_range(-29.0, 29.0)), _rng.randf_range(-0.08, 0.08), _rng.randf() < 0.5)

func _make_materials() -> void:
	_mat_asphalt = _material(Color(0.115, 0.112, 0.105), 0.95)
	_mat_dirt = _material(Color(0.31, 0.235, 0.155), 0.98)
	_mat_concrete = _material(Color(0.45, 0.43, 0.39), 0.96)
	_mat_plaster_a = _material(Color(0.58, 0.48, 0.38), 0.94)
	_mat_plaster_b = _material(Color(0.39, 0.48, 0.49), 0.93)
	_mat_brick = _material(Color(0.43, 0.20, 0.13), 0.95)
	_mat_roof = _material(Color(0.24, 0.12, 0.08), 0.90)
	_mat_metal = _material(Color(0.12, 0.13, 0.135), 0.58, 0.24)
	_mat_glass = _material(Color(0.075, 0.12, 0.145), 0.22, 0.05)
	_mat_grass = _material(Color(0.31, 0.35, 0.16), 0.98)
	_mat_wood = _material(Color(0.22, 0.13, 0.075), 0.96)
	_mat_marker = _material(Color(0.02, 0.34, 0.46), 0.35)
	_mat_marker.emission_enabled = true
	_mat_marker.emission = Color(0.02, 0.62, 0.94)
	_mat_marker.emission_energy_multiplier = 1.55

func _add_ground_and_roads() -> void:
	_add_static_box("Ground", Vector3(0.0, -0.34, 0.0), Vector3(cell_size, 0.64, cell_size), _mat_dirt, true)
	var road_width := 13.0
	_add_visual_box("Road_NS", Vector3(0.0, 0.005, 0.0), Vector3(road_width, 0.045, cell_size), _mat_asphalt)
	_add_visual_box("Road_EW", Vector3(0.0, 0.010, 0.0), Vector3(cell_size, 0.045, road_width), _mat_asphalt)

	for side in [-1.0, 1.0]:
		_add_visual_box("Curb_NS", Vector3(side * 7.35, 0.09, 0.0), Vector3(1.45, 0.16, cell_size), _mat_concrete)
		_add_visual_box("Curb_EW", Vector3(0.0, 0.095, side * 7.35), Vector3(cell_size, 0.16, 1.45), _mat_concrete)

	var line_mat := _material(Color(0.72, 0.66, 0.48), 0.92)
	for offset in range(-42, 43, 9):
		_add_visual_box("RoadDash_NS", Vector3(0.0, 0.047, float(offset)), Vector3(0.12, 0.025, 3.8), line_mat)
		_add_visual_box("RoadDash_EW", Vector3(float(offset), 0.052, 0.0), Vector3(3.8, 0.025, 0.12), line_mat)

func _add_city_blocks() -> void:
	var road_half := 9.2
	var half := cell_size * 0.5
	var centers := [
		Vector3(-(road_half + half) * 0.50, 0.0, -(road_half + half) * 0.50),
		Vector3((road_half + half) * 0.50, 0.0, -(road_half + half) * 0.50),
		Vector3(-(road_half + half) * 0.50, 0.0, (road_half + half) * 0.50),
		Vector3((road_half + half) * 0.50, 0.0, (road_half + half) * 0.50)
	]

	for quadrant in centers.size():
		if cell_coord == Vector2i.ZERO and quadrant == 0:
			continue
		var base_center: Vector3 = centers[quadrant]
		var count := 1
		if detail_scale >= 0.58:
			count = 2
		if detail_scale >= 0.88 and _rng.randf() > 0.38:
			count = 3

		for index in count:
			var spread := 7.0 if count > 1 else 0.0
			var local_shift := Vector3(
				_rng.randf_range(-spread, spread),
				0.0,
				_rng.randf_range(-spread, spread)
			)
			var width := _rng.randf_range(11.0, 18.0)
			var depth := _rng.randf_range(10.0, 16.0)
			var floors := _rng.randi_range(1, 3 if detail_scale >= 0.72 else 2)
			var height := 3.25 * float(floors) + _rng.randf_range(0.3, 1.0)
			var material := _choose_wall_material()
			_add_building(base_center + local_shift, width, depth, height, floors, quadrant * 4 + index, material)

func _choose_wall_material() -> StandardMaterial3D:
	var roll := _rng.randf()
	if roll < 0.34:
		return _mat_plaster_a
	if roll < 0.67:
		return _mat_plaster_b
	return _mat_brick

func _add_building(center: Vector3, width: float, depth: float, height: float, floors: int, index: int, wall_material: Material) -> void:
	_add_static_box(
		"Building_%d" % index,
		center + Vector3(0.0, height * 0.5, 0.0),
		Vector3(width, height, depth),
		wall_material,
		true
	)
	_add_visual_box("Foundation_%d" % index, center + Vector3(0.0, 0.22, 0.0), Vector3(width + 0.25, 0.44, depth + 0.25), _mat_concrete)

	if detail_scale >= 0.62:
		_add_facade(center, width, depth, height, floors, index)
	if detail_scale >= 0.52:
		if _rng.randf() < 0.55:
			_add_gable_roof(center, width, depth, height, index)
		else:
			_add_flat_roof(center, width, depth, height, index)

func _add_facade(center: Vector3, width: float, depth: float, height: float, floors: int, index: int) -> void:
	var toward_road_z := -signf(center.z)
	if is_zero_approx(toward_road_z):
		toward_road_z = 1.0
	var front_z := center.z + toward_road_z * (depth * 0.5 + 0.035)
	var window_rows := maxi(1, floors)
	var columns := 2 if width < 15.0 else 3

	for row in window_rows:
		var window_y := 1.65 + float(row) * 3.05
		if window_y > height - 0.55:
			continue
		for col in columns:
			var t := (float(col) + 1.0) / (float(columns) + 1.0)
			var window_x := center.x - width * 0.5 + width * t
			_add_visual_box(
				"Window_%d_%d_%d" % [index, row, col],
				Vector3(window_x, window_y, front_z),
				Vector3(1.18, 1.18, 0.07),
				_mat_glass
			)
			_add_visual_box(
				"WindowLintel_%d_%d_%d" % [index, row, col],
				Vector3(window_x, window_y + 0.68, front_z + toward_road_z * 0.015),
				Vector3(1.40, 0.12, 0.09),
				_mat_concrete
			)

	var door_x := center.x + width * (_rng.randf_range(-0.25, 0.25))
	_add_visual_box("Door_%d" % index, Vector3(door_x, 1.02, front_z + toward_road_z * 0.025), Vector3(1.05, 2.05, 0.09), _mat_wood)
	_add_visual_box("DoorStep_%d" % index, Vector3(door_x, 0.12, front_z + toward_road_z * 0.45), Vector3(1.45, 0.20, 0.75), _mat_concrete)

func _add_gable_roof(center: Vector3, width: float, depth: float, height: float, index: int) -> void:
	var angle := deg_to_rad(24.0)
	var roof_depth := depth * 0.58
	var y := height + 0.40
	_add_visual_box_rotated(
		"RoofA_%d" % index,
		center + Vector3(0.0, y, depth * 0.22),
		Vector3(width + 0.55, 0.16, roof_depth),
		Vector3(angle, 0.0, 0.0),
		_mat_roof
	)
	_add_visual_box_rotated(
		"RoofB_%d" % index,
		center + Vector3(0.0, y, -depth * 0.22),
		Vector3(width + 0.55, 0.16, roof_depth),
		Vector3(-angle, 0.0, 0.0),
		_mat_roof
	)

func _add_flat_roof(center: Vector3, width: float, depth: float, height: float, index: int) -> void:
	_add_visual_box("RoofSlab_%d" % index, center + Vector3(0.0, height + 0.16, 0.0), Vector3(width + 0.35, 0.30, depth + 0.35), _mat_concrete)
	if detail_scale >= 0.78 and _rng.randf() < 0.65:
		_add_water_tank(center + Vector3(width * 0.22, height + 1.15, depth * 0.18))

func _add_water_tank(local_position: Vector3) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.62
	cylinder.bottom_radius = 0.62
	cylinder.height = 1.35
	cylinder.radial_segments = 10
	var mesh := MeshInstance3D.new()
	mesh.name = "RoofWaterTank"
	mesh.mesh = cylinder
	mesh.material_override = _mat_metal
	mesh.position = local_position
	add_child(mesh)

func _add_grass_clusters() -> void:
	var density := float(Settings.get_value("graphics/vegetation_density", 0.60))
	var count := clampi(roundi(74.0 * density * detail_scale), 0, 90)
	if count <= 0:
		return

	var blade := CylinderMesh.new()
	blade.top_radius = 0.015
	blade.bottom_radius = 0.085
	blade.height = 0.55
	blade.radial_segments = 3
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = blade
	multi.instance_count = count

	for i in count:
		var x := 0.0
		var z := 0.0
		for attempt in 8:
			x = _rng.randf_range(-cell_size * 0.47, cell_size * 0.47)
			z = _rng.randf_range(-cell_size * 0.47, cell_size * 0.47)
			if absf(x) > 9.4 and absf(z) > 9.4:
				break
		var scale_value := _rng.randf_range(0.65, 1.55)
		var basis := Basis.IDENTITY.scaled(Vector3(scale_value, scale_value, scale_value))
		basis = basis.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		multi.set_instance_transform(i, Transform3D(basis, Vector3(x, 0.27, z)))

	var instance := MultiMeshInstance3D.new()
	instance.name = "DryGrass"
	instance.multimesh = multi
	instance.material_override = _mat_grass
	add_child(instance)

func _add_roadside_props() -> void:
	for z in [-31.0, 31.0]:
		_add_power_pole(Vector3(-8.6, 0.0, z))
	if detail_scale >= 0.80:
		for position_value in [Vector3(17.0, 0.0, 17.0), Vector3(-19.0, 0.0, 26.0)]:
			if _rng.randf() < 0.74:
				_add_tree(position_value + Vector3(_rng.randf_range(-4.0, 4.0), 0.0, _rng.randf_range(-4.0, 4.0)))

func _add_power_pole(local_position: Vector3) -> void:
	_add_cylinder("PowerPole", local_position + Vector3(0.0, 3.3, 0.0), 0.11, 6.6, _mat_wood)
	_add_visual_box("PowerCrossbar", local_position + Vector3(0.0, 6.0, 0.0), Vector3(2.2, 0.13, 0.13), _mat_wood)
	for x in [-0.86, 0.0, 0.86]:
		_add_cylinder("Insulator", local_position + Vector3(x, 6.18, 0.0), 0.045, 0.24, _mat_glass)

func _add_tree(local_position: Vector3) -> void:
	_add_cylinder("TreeTrunk", local_position + Vector3(0.0, 1.25, 0.0), 0.24, 2.5, _mat_wood)
	var crown := SphereMesh.new()
	crown.radius = 1.45
	crown.height = 2.55
	crown.radial_segments = 10
	crown.rings = 5
	var mesh := MeshInstance3D.new()
	mesh.name = "TreeCrown"
	mesh.mesh = crown
	mesh.material_override = _mat_grass
	mesh.position = local_position + Vector3(0.0, 3.15, 0.0)
	mesh.scale = Vector3(1.0, 1.15, 0.92)
	add_child(mesh)

func _add_origin_landmarks() -> void:
	var center := Vector3(-25.0, 0.0, -25.0)
	_add_static_box("Garage", center + Vector3(0.0, 2.8, 0.0), Vector3(25.5, 5.6, 19.0), _mat_plaster_b, true)
	_add_gable_roof(center, 25.5, 19.0, 5.6, 900)
	_add_visual_box("GarageDoor", Vector3(-25.0, 2.15, -15.45), Vector3(11.5, 4.3, 0.16), _mat_metal)
	_add_visual_box("GarageDoorInset", Vector3(-25.0, 2.15, -15.34), Vector3(10.6, 3.55, 0.05), _mat_concrete)
	_add_visual_box("GarageSign", Vector3(-25.0, 5.10, -15.29), Vector3(10.2, 0.72, 0.10), _mat_brick)
	_add_visual_box("SideWindow", Vector3(-34.5, 2.75, -15.28), Vector3(2.8, 1.55, 0.08), _mat_glass)
	_add_visual_box("Workbench", Vector3(-31.0, 0.95, -21.0), Vector3(5.8, 0.95, 1.4), _mat_wood)
	_add_visual_box("MissionBoard", Vector3(-34.3, 2.0, -20.4), Vector3(0.10, 2.15, 2.55), _mat_wood)
	_add_parked_car(Vector3(-17.0, 0.0, -20.2), 0.0, true)

	_add_interaction("garage_open", "Open garage", Vector3(-25.0, 1.0, -12.8))
	_add_interaction("job_board", "Check job board", Vector3(-33.1, 1.4, -18.7))
	_add_interaction("delivery_pickup", "Collect package", Vector3(-29.0, 0.5, -18.5))
	_add_interaction("suspicious_car_inspect", "Inspect damaged car", Vector3(-17.0, 0.6, -17.7))

func _add_parked_car(local_position: Vector3, yaw: float, damaged: bool) -> void:
	var root := Node3D.new()
	root.name = "DamagedCar" if damaged else "ParkedCar"
	root.position = local_position
	root.rotation.y = yaw
	add_child(root)
	var body_mat := _material(Color(0.42, 0.18, 0.08) if damaged else Color(0.52, 0.40, 0.08), 0.62, 0.18)
	_add_box_to(root, "CarBody", Vector3(0.0, 0.68, 0.0), Vector3(4.1, 0.78, 1.85), body_mat)
	_add_box_to(root, "CarCabin", Vector3(-0.20, 1.32, 0.0), Vector3(2.15, 0.73, 1.60), _mat_glass)
	_add_box_to(root, "FrontBumper", Vector3(-2.08, 0.55, 0.0), Vector3(0.13, 0.28, 1.88), _mat_metal)
	for x in [-1.38, 1.30]:
		for z in [-0.92, 0.92]:
			_add_cylinder_to(root, "Wheel", Vector3(x, 0.45, z), 0.37, 0.22, _mat_metal, Vector3(PI * 0.5, 0.0, 0.0))

func _add_interaction(id: String, text: String, local_position: Vector3) -> void:
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.58
	marker_mesh.bottom_radius = 0.58
	marker_mesh.height = 0.03
	marker_mesh.radial_segments = 16
	var marker := MeshInstance3D.new()
	marker.mesh = marker_mesh
	marker.material_override = _mat_marker
	marker.position = local_position + Vector3(0.0, 0.03, 0.0)
	add_child(marker)

	var point := InteractionPoint.new().configure(id, text, {"cell": [cell_coord.x, cell_coord.y]})
	point.position = local_position
	add_child(point)

func _add_static_box(node_name: String, local_position: Vector3, size: Vector3, material: Material, collision: bool) -> void:
	_add_visual_box(node_name, local_position, size, material)
	if not collision:
		return
	var body := StaticBody3D.new()
	body.name = "%s_Collision" % node_name
	body.position = local_position
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)
	add_child(body)

func _add_visual_box(node_name: String, local_position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	return _add_visual_box_rotated(node_name, local_position, size, Vector3.ZERO, material)

func _add_visual_box_rotated(node_name: String, local_position: Vector3, size: Vector3, rotation_radians: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = local_position
	mesh.rotation = rotation_radians
	add_child(mesh)
	return mesh

func _add_box_to(parent: Node3D, node_name: String, local_position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = local_position
	parent.add_child(mesh)
	return mesh

func _add_cylinder(node_name: String, local_position: Vector3, radius: float, height: float, material: Material, rotation_radians: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_resource := CylinderMesh.new()
	mesh_resource.top_radius = radius
	mesh_resource.bottom_radius = radius
	mesh_resource.height = height
	mesh_resource.radial_segments = 8
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = mesh_resource
	mesh.material_override = material
	mesh.position = local_position
	mesh.rotation = rotation_radians
	add_child(mesh)
	return mesh

func _add_cylinder_to(parent: Node3D, node_name: String, local_position: Vector3, radius: float, height: float, material: Material, rotation_radians: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_resource := CylinderMesh.new()
	mesh_resource.top_radius = radius
	mesh_resource.bottom_radius = radius
	mesh_resource.height = height
	mesh_resource.radial_segments = 10
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = mesh_resource
	mesh.material_override = material
	mesh.position = local_position
	mesh.rotation = rotation_radians
	parent.add_child(mesh)
	return mesh

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
