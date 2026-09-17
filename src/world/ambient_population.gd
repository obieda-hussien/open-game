extends Node3D

@export var player_path: NodePath
@export var simulation_radius := 220.0

var _player: Node3D
var _traffic_instance: MultiMeshInstance3D
var _crowd_instance: MultiMeshInstance3D
var _traffic_states: Array = []
var _crowd_states: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_player = get_node_or_null(player_path)
	_rng.randomize()
	EventBus.setting_changed.connect(_on_setting_changed)
	_rebuild()

func _process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(_player):
		return
	_update_traffic(delta)
	_update_crowd(delta)

func _rebuild() -> void:
	if is_instance_valid(_traffic_instance):
		_traffic_instance.queue_free()
	if is_instance_valid(_crowd_instance):
		_crowd_instance.queue_free()

	var quality := PerformanceDirector.quality_multiplier()
	var traffic_density := float(Settings.get_value("graphics/traffic_density", 0.55)) * quality
	var npc_density := float(Settings.get_value("graphics/npc_density", 0.60)) * quality

	_traffic_states.clear()
	_crowd_states.clear()
	_traffic_instance = _create_traffic_multimesh(clampi(roundi(28.0 * traffic_density), 0, 36))
	_crowd_instance = _create_crowd_multimesh(clampi(roundi(52.0 * npc_density), 0, 72))
	add_child(_traffic_instance)
	add_child(_crowd_instance)

func _create_traffic_multimesh(count: int) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(3.8, 1.25, 1.75)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.11, 0.13, 0.16)
	material.metallic = 0.30
	material.roughness = 0.42
	mesh.material = material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count

	for i in count:
		var axis_x := i % 2 == 0
		var lane := -4.0 if i % 4 < 2 else 4.0
		var state := {
			"axis_x": axis_x,
			"lane": lane,
			"position": _rng.randf_range(-simulation_radius, simulation_radius),
			"speed": _rng.randf_range(7.0, 16.0),
			"direction": -1.0 if i % 3 == 0 else 1.0
		}
		_traffic_states.append(state)
	_update_traffic_transforms(multimesh)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.visibility_range_end = simulation_radius * 1.25
	return instance

func _create_crowd_multimesh(count: int) -> MultiMeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.30
	mesh.height = 1.55
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.26, 0.25, 0.24)
	material.roughness = 0.88
	mesh.material = material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count

	for i in count:
		_crowd_states.append({
			"angle": _rng.randf_range(0.0, TAU),
			"radius": _rng.randf_range(22.0, simulation_radius * 0.86),
			"speed": _rng.randf_range(0.08, 0.22),
			"phase": _rng.randf_range(0.0, TAU)
		})
	_update_crowd_transforms(multimesh, 0.0)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.visibility_range_end = simulation_radius
	return instance

func _update_traffic(delta: float) -> void:
	if not is_instance_valid(_traffic_instance) or _traffic_instance.multimesh == null:
		return
	for state in _traffic_states:
		state["position"] = float(state["position"]) + float(state["speed"]) * float(state["direction"]) * delta
		if absf(float(state["position"])) > simulation_radius:
			state["position"] = -signf(float(state["position"])) * simulation_radius
	_update_traffic_transforms(_traffic_instance.multimesh)

func _update_traffic_transforms(multimesh: MultiMesh) -> void:
	var origin := _player.global_position if is_instance_valid(_player) else Vector3.ZERO
	for i in _traffic_states.size():
		var state: Dictionary = _traffic_states[i]
		var axis_x := bool(state["axis_x"])
		var p := float(state["position"])
		var lane := float(state["lane"])
		var position := origin
		var yaw := 0.0
		if axis_x:
			position += Vector3(p, 0.7, lane)
			yaw = PI * 0.5
		else:
			position += Vector3(lane, 0.7, p)
		var basis := Basis(Vector3.UP, yaw)
		multimesh.set_instance_transform(i, Transform3D(basis, position))

func _update_crowd(delta: float) -> void:
	if not is_instance_valid(_crowd_instance) or _crowd_instance.multimesh == null:
		return
	_update_crowd_transforms(_crowd_instance.multimesh, delta)

func _update_crowd_transforms(multimesh: MultiMesh, delta: float) -> void:
	var origin := _player.global_position if is_instance_valid(_player) else Vector3.ZERO
	for i in _crowd_states.size():
		var state: Dictionary = _crowd_states[i]
		state["angle"] = fmod(float(state["angle"]) + float(state["speed"]) * delta, TAU)
		var angle := float(state["angle"])
		var radius := float(state["radius"])
		var position := origin + Vector3(cos(angle) * radius, 0.82, sin(angle) * radius)
		var basis := Basis(Vector3.UP, -angle + PI * 0.5)
		multimesh.set_instance_transform(i, Transform3D(basis, position))

func _on_setting_changed(key: String, _value: Variant) -> void:
	if key in ["graphics/traffic_density", "graphics/npc_density", "graphics/preset"]:
		call_deferred("_rebuild")
