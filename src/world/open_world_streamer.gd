extends Node3D

@export var player_path: NodePath
@export var cell_size := 96.0
@export var authored_cells_root := "res://content/world/cells"
@export var refresh_seconds := 0.20

var _player: Node3D
var _loaded_cells: Dictionary = {}
var _pending_paths: Dictionary = {}
var _procedural_queue: Array[Vector2i] = []
var _refresh_elapsed := 999.0
var _last_player_cell := Vector2i(999999, 999999)

func _ready() -> void:
	_player = get_node_or_null(player_path)
	EventBus.setting_changed.connect(_on_setting_changed)
	_refresh_needed_cells(true)

func _process(delta: float) -> void:
	_poll_threaded_loads()
	_instantiate_one_procedural_cell()

	_refresh_elapsed += delta
	if _refresh_elapsed < refresh_seconds:
		return
	_refresh_elapsed = 0.0
	_refresh_needed_cells(false)

func _refresh_needed_cells(force: bool) -> void:
	if not is_instance_valid(_player):
		return
	var center := _world_to_cell(_player.global_position)
	if not force and center == _last_player_cell:
		return
	_last_player_cell = center

	var active_radius := _active_radius()
	var keep_radius := active_radius + 1
	var wanted: Dictionary = {}

	for x in range(center.x - active_radius, center.x + active_radius + 1):
		for y in range(center.y - active_radius, center.y + active_radius + 1):
			var coord := Vector2i(x, y)
			if _cell_distance(coord, center) <= float(active_radius) + 0.45:
				wanted[coord] = true
				if not _loaded_cells.has(coord) and not _is_pending(coord) and not _procedural_queue.has(coord):
					_request_cell(coord)

	for coord_variant in _loaded_cells.keys():
		var coord: Vector2i = coord_variant
		if _cell_distance(coord, center) > float(keep_radius) + 0.55:
			var node: Node = _loaded_cells[coord]
			_loaded_cells.erase(coord)
			if is_instance_valid(node):
				node.queue_free()

	_prune_queued_cells(wanted, center, keep_radius)

func _request_cell(coord: Vector2i) -> void:
	var authored_path := "%s/cell_%d_%d.tscn" % [authored_cells_root, coord.x, coord.y]
	if ResourceLoader.exists(authored_path):
		var err := ResourceLoader.load_threaded_request(authored_path, "PackedScene", false)
		if err == OK:
			_pending_paths[authored_path] = coord
			return
	_procedural_queue.append(coord)

func _poll_threaded_loads() -> void:
	for path_variant in _pending_paths.keys():
		var path := String(path_variant)
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var coord: Vector2i = _pending_paths[path]
		_pending_paths.erase(path)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			_procedural_queue.append(coord)
			continue
		var resource := ResourceLoader.load_threaded_get(path)
		if not (resource is PackedScene):
			_procedural_queue.append(coord)
			continue
		var instance := (resource as PackedScene).instantiate()
		if instance is Node3D:
			instance.position = Vector3(float(coord.x) * cell_size, 0.0, float(coord.y) * cell_size)
			add_child(instance)
			_loaded_cells[coord] = instance
		else:
			instance.queue_free()

func _instantiate_one_procedural_cell() -> void:
	if _procedural_queue.is_empty():
		return
	var coord := _take_nearest_queued()
	if _loaded_cells.has(coord):
		return

	var detail := clampf(PerformanceDirector.quality_multiplier(), 0.45, 1.0)
	var cell := WorldCell.new().configure(coord, cell_size, detail)
	add_child(cell)
	_loaded_cells[coord] = cell

func _take_nearest_queued() -> Vector2i:
	var best_index := 0
	var best_distance := INF
	for i in _procedural_queue.size():
		var distance := _cell_distance(_procedural_queue[i], _last_player_cell)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return _procedural_queue.pop_at(best_index)

func _is_pending(coord: Vector2i) -> bool:
	for pending_coord in _pending_paths.values():
		if pending_coord == coord:
			return true
	return false

func _prune_queued_cells(wanted: Dictionary, center: Vector2i, keep_radius: int) -> void:
	var filtered: Array[Vector2i] = []
	for coord in _procedural_queue:
		if wanted.has(coord) or _cell_distance(coord, center) <= float(keep_radius):
			filtered.append(coord)
	_procedural_queue = filtered

func _active_radius() -> int:
	var requested := int(Settings.get_value("graphics/draw_distance", 2))
	var quality := PerformanceDirector.quality_multiplier()
	if quality < 0.70:
		return mini(requested, 1)
	if quality < 0.90:
		return mini(requested, 2)
	return clampi(requested, 1, 4)

func _world_to_cell(world_position: Vector3) -> Vector2i:
	return Vector2i(
		floori((world_position.x + cell_size * 0.5) / cell_size),
		floori((world_position.z + cell_size * 0.5) / cell_size)
	)

func _cell_distance(a: Vector2i, b: Vector2i) -> float:
	return Vector2(float(a.x - b.x), float(a.y - b.y)).length()

func _on_setting_changed(key: String, _value: Variant) -> void:
	if key.begins_with("graphics/"):
		_refresh_needed_cells(true)
