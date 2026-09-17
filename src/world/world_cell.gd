class_name WorldCell
extends Node3D

var cell_coord := Vector2i.ZERO
var cell_size := 96.0
var detail_scale := 1.0
var _rng := RandomNumberGenerator.new()

var _mat_road: StandardMaterial3D
var _mat_sidewalk: StandardMaterial3D
var _mat_building_a: StandardMaterial3D
var _mat_building_b: StandardMaterial3D
var _mat_metal: StandardMaterial3D
var _mat_red: StandardMaterial3D
var _mat_neon: StandardMaterial3D
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
	_add_ground()
	_add_city_blocks()
	if cell_coord == Vector2i.ZERO:
		_add_origin_landmarks()
	elif detail_scale > 0.55:
		_add_emissive_street_furniture()

func _make_materials() -> void:
	_mat_road = _material(Color(0.035, 0.042, 0.050), 0.88)
	_mat_sidewalk = _material(Color(0.34, 0.31, 0.27), 0.94)
	_mat_building_a = _material(Color(0.30, 0.22, 0.17), 0.90)
	_mat_building_b = _material(Color(0.18, 0.19, 0.21), 0.86)
	_mat_metal = _material(Color(0.07, 0.08, 0.10), 0.42, 0.42)
	_mat_red = _material(Color(0.43, 0.045, 0.025), 0.52, 0.20)
	_mat_neon = _material(Color(0.84, 0.18, 0.035), 0.28)
	_mat_neon.emission_enabled = true
	_mat_neon.emission = Color(1.0, 0.13, 0.025)
	_mat_neon.emission_energy_multiplier = 4.0
	_mat_marker = _material(Color(0.02, 0.35, 0.48), 0.25)
	_mat_marker.emission_enabled = true
	_mat_marker.emission = Color(0.02, 0.70, 1.0)
	_mat_marker.emission_energy_multiplier = 2.2

func _add_ground() -> void:
	_add_static_box(
		"Ground",
		Vector3(0.0, -0.32, 0.0),
		Vector3(cell_size, 0.60, cell_size),
		_mat_sidewalk,
		true
	)
	var road_width := 14.0
	_add_visual_box("Road_NS", Vector3(0.0, 0.01, 0.0), Vector3(road_width, 0.04, cell_size), _mat_road)
	_add_visual_box("Road_EW", Vector3(0.0, 0.015, 0.0), Vector3(cell_size, 0.04, road_width), _mat_road)

	var mark_material := _material(Color(0.72, 0.68, 0.54), 0.78)
	for offset in range(-40, 41, 10):
		_add_visual_box("RoadMark", Vector3(0.0, 0.05, float(offset)), Vector3(0.15, 0.03, 2.8), mark_material)
		_add_visual_box("RoadMark", Vector3(float(offset), 0.055, 0.0), Vector3(2.8, 0.03, 0.15), mark_material)

func _add_city_blocks() -> void:
	var road_half := 9.0
	var block_extent := cell_size * 0.5 - road_half - 2.0
	var centers := [
		Vector3(-road_half - block_extent * 0.5, 0.0, -road_half - block_extent * 0.5),
		Vector3( road_half + block_extent * 0.5, 0.0, -road_half - block_extent * 0.5),
		Vector3(-road_half - block_extent * 0.5, 0.0,  road_half + block_extent * 0.5),
		Vector3( road_half + block_extent * 0.5, 0.0,  road_half + block_extent * 0.5)
	]

	for index in centers.size():
		if cell_coord == Vector2i.ZERO and index == 0:
			continue
		var height := _rng.randf_range(8.0, 25.0)
		var width := _rng.randf_range(block_extent * 0.55, block_extent * 0.90)
		var depth := _rng.randf_range(block_extent * 0.55, block_extent * 0.90)
		var material := _mat_building_a if _rng.randf() > 0.45 else _mat_building_b
		_add_static_box(
			"Building_%d" % index,
			centers[index] + Vector3(0.0, height * 0.5, 0.0),
			Vector3(width, height, depth),
			material,
			true
		)
		if detail_scale >= 0.70:
			_add_rooftop_props(centers[index], height, width, depth)

func _add_rooftop_props(center: Vector3, height: float, width: float, depth: float) -> void:
	if _rng.randf() < 0.55:
		var tank_radius := 0.7
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = tank_radius
		cylinder.bottom_radius = tank_radius
		cylinder.height = 1.3
		var mesh := MeshInstance3D.new()
		mesh.mesh = cylinder
		mesh.material_override = _mat_metal
		mesh.position = center + Vector3(width * 0.20, height + 0.65, depth * 0.20)
		add_child(mesh)

func _add_origin_landmarks() -> void:
	_add_static_box("Garage", Vector3(-24.0, 3.0, -25.0), Vector3(25.0, 6.0, 20.0), _mat_building_b, true)
	_add_visual_box("GarageDoor", Vector3(-24.0, 2.15, -14.85), Vector3(12.0, 4.3, 0.20), _mat_metal)
	_add_visual_box("GarageSign", Vector3(-24.0, 5.20, -14.68), Vector3(11.0, 0.65, 0.14), _mat_red)
	_add_visual_box("GarageNeon", Vector3(-24.0, 5.20, -14.50), Vector3(8.5, 0.10, 0.06), _mat_neon)
	_add_visual_box("Workbench", Vector3(-29.0, 1.0, -20.0), Vector3(5.5, 1.0, 1.5), _mat_metal)
	_add_visual_box("MissionBoard", Vector3(-33.5, 2.0, -20.1), Vector3(0.12, 2.0, 2.4), _mat_red)
	_add_visual_box("SuspiciousCarBody", Vector3(-17.0, 0.8, -20.0), Vector3(4.5, 1.15, 2.0), _mat_red)
	_add_visual_box("SuspiciousCarCabin", Vector3(-17.1, 1.65, -20.0), Vector3(2.1, 0.85, 1.75), _mat_metal)

	for light_position in [
		Vector3(-30.0, 4.2, -15.0),
		Vector3(-18.0, 4.0, -15.0),
		Vector3(-8.0, 4.3, -3.0)
	]:
		var light := OmniLight3D.new()
		light.position = light_position
		light.light_color = Color(1.0, 0.42, 0.20)
		light.light_energy = 3.0
		light.omni_range = 12.0
		light.shadow_enabled = false
		add_child(light)

	_add_interaction("garage_open", "Garage opened", Vector3(-24.0, 1.0, -12.3))
	_add_interaction("job_board", "Checked the job board", Vector3(-33.0, 1.4, -18.0))
	_add_interaction("delivery_pickup", "Package collected", Vector3(-28.0, 0.5, -18.2))
	_add_interaction("suspicious_car_inspect", "You inspect the damaged car", Vector3(-17.0, 0.6, -17.7))

func _add_emissive_street_furniture() -> void:
	for corner in [Vector3(-7.2, 0.0, -7.2), Vector3(7.2, 0.0, 7.2)]:
		_add_visual_box("LampPole", corner + Vector3(0.0, 2.8, 0.0), Vector3(0.16, 5.6, 0.16), _mat_metal)
		_add_visual_box("LampGlow", corner + Vector3(0.0, 5.5, 0.0), Vector3(0.75, 0.18, 0.38), _mat_neon)

func _add_interaction(id: String, text: String, local_position: Vector3) -> void:
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.62
	marker_mesh.bottom_radius = 0.62
	marker_mesh.height = 0.035
	var marker := MeshInstance3D.new()
	marker.mesh = marker_mesh
	marker.material_override = _mat_marker
	marker.position = local_position + Vector3(0.0, 0.035, 0.0)
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
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = local_position
	add_child(mesh)
	return mesh

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
