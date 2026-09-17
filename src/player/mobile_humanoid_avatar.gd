extends Node3D

var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _chest: Node3D
var _phase := 0.0
var _crouch_blend := 0.0

func _ready() -> void:
	_build_avatar()

func set_motion_state(speed: float, sprinting: bool, crouching: bool, delta: float) -> void:
	var normalized_speed := clampf(speed / 8.4, 0.0, 1.0)
	var cadence := 1.55 + normalized_speed * (1.35 if sprinting else 0.75)
	_phase = fmod(_phase + delta * cadence, TAU)
	var swing := sin(_phase) * normalized_speed
	var arm_angle := 0.68 * swing
	var leg_angle := 0.58 * swing

	if is_instance_valid(_left_arm):
		_left_arm.rotation.x = lerp_angle(_left_arm.rotation.x, arm_angle, 1.0 - exp(-12.0 * delta))
	if is_instance_valid(_right_arm):
		_right_arm.rotation.x = lerp_angle(_right_arm.rotation.x, -arm_angle, 1.0 - exp(-12.0 * delta))
	if is_instance_valid(_left_leg):
		_left_leg.rotation.x = lerp_angle(_left_leg.rotation.x, -leg_angle, 1.0 - exp(-14.0 * delta))
	if is_instance_valid(_right_leg):
		_right_leg.rotation.x = lerp_angle(_right_leg.rotation.x, leg_angle, 1.0 - exp(-14.0 * delta))

	_crouch_blend = lerpf(_crouch_blend, 1.0 if crouching else 0.0, 1.0 - exp(-10.0 * delta))
	position.y = -0.28 * _crouch_blend
	if is_instance_valid(_chest):
		_chest.rotation.x = lerpf(_chest.rotation.x, 0.12 * _crouch_blend + absf(swing) * 0.025, 1.0 - exp(-9.0 * delta))

func _build_avatar() -> void:
	var skin := _material(Color(0.53, 0.34, 0.24), 0.88)
	var shirt := _material(Color(0.095, 0.115, 0.135), 0.90)
	var pants := _material(Color(0.075, 0.085, 0.10), 0.94)
	var boots := _material(Color(0.055, 0.043, 0.035), 0.93)
	var hair := _material(Color(0.025, 0.020, 0.018), 0.96)
	var canvas := _material(Color(0.16, 0.13, 0.09), 0.96)
	var metal := _material(Color(0.12, 0.13, 0.14), 0.48, 0.30)

	_chest = Node3D.new()
	_chest.name = "Chest"
	add_child(_chest)
	_add_box(_chest, "Torso", Vector3(0.0, 1.30, 0.0), Vector3(0.52, 0.58, 0.28), shirt)
	_add_box(_chest, "Waist", Vector3(0.0, 0.98, 0.0), Vector3(0.43, 0.20, 0.25), pants)
	_add_box(_chest, "ToolPouch", Vector3(0.26, 0.98, 0.03), Vector3(0.14, 0.19, 0.10), canvas)
	_add_box(_chest, "BackPanel", Vector3(0.0, 1.28, 0.17), Vector3(0.39, 0.45, 0.07), canvas)
	_add_box(_chest, "BackMetal", Vector3(0.0, 1.25, 0.215), Vector3(0.22, 0.08, 0.025), metal)

	_add_sphere(self, "Head", Vector3(0.0, 1.69, 0.0), 0.16, skin)
	_add_sphere(self, "Hair", Vector3(0.0, 1.76, -0.005), 0.165, hair, Vector3(1.0, 0.55, 1.0))
	_add_box(self, "Neck", Vector3(0.0, 1.51, 0.0), Vector3(0.13, 0.12, 0.13), skin)

	_left_arm = _make_limb("LeftArm", Vector3(-0.33, 1.48, 0.0), Vector3(0.13, 0.62, 0.14), shirt, skin)
	_right_arm = _make_limb("RightArm", Vector3(0.33, 1.48, 0.0), Vector3(0.13, 0.62, 0.14), shirt, skin)
	_left_leg = _make_leg("LeftLeg", Vector3(-0.13, 0.93, 0.0), pants, boots)
	_right_leg = _make_leg("RightLeg", Vector3(0.13, 0.93, 0.0), pants, boots)

func _make_limb(node_name: String, pivot_position: Vector3, size: Vector3, clothing: Material, skin: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = pivot_position
	add_child(pivot)
	_add_box(pivot, "%sSleeve" % node_name, Vector3(0.0, -size.y * 0.32, 0.0), Vector3(size.x * 1.12, size.y * 0.48, size.z * 1.12), clothing)
	_add_box(pivot, "%sForearm" % node_name, Vector3(0.0, -size.y * 0.72, 0.0), Vector3(size.x * 0.86, size.y * 0.36, size.z * 0.86), skin)
	_add_sphere(pivot, "%sHand" % node_name, Vector3(0.0, -size.y * 0.98, 0.0), size.x * 0.49, skin, Vector3(0.82, 1.08, 0.72))
	return pivot

func _make_leg(node_name: String, pivot_position: Vector3, pants: Material, boots: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = pivot_position
	add_child(pivot)
	_add_box(pivot, "%sThigh" % node_name, Vector3(0.0, -0.22, 0.0), Vector3(0.18, 0.44, 0.20), pants)
	_add_box(pivot, "%sShin" % node_name, Vector3(0.0, -0.61, 0.0), Vector3(0.16, 0.34, 0.18), pants)
	_add_box(pivot, "%sBoot" % node_name, Vector3(0.0, -0.82, -0.035), Vector3(0.19, 0.16, 0.31), boots)
	return pivot

func _add_box(parent: Node, node_name: String, local_position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_resource := BoxMesh.new()
	mesh_resource.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = mesh_resource
	mesh.material_override = material
	mesh.position = local_position
	parent.add_child(mesh)
	return mesh

func _add_sphere(parent: Node, node_name: String, local_position: Vector3, radius: float, material: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = sphere
	mesh.material_override = material
	mesh.position = local_position
	mesh.scale = scale_value
	parent.add_child(mesh)
	return mesh

func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
