extends SceneTree

var failures := 0

func _initialize() -> void:
	print("[tests] Last Shift headless smoke tests")
	_test_main_scene()
	_test_mobile_contract()
	_test_production_asset_contract()
	_test_vehicle_contract()
	_test_json("res://data/missions/prologue.json", "missions")
	_test_json("res://data/events/world_events.json", "events")
	_test_json("res://data/assets/remote_assets.json", "assets")
	_test_mission_targets()
	if failures == 0:
		print("[tests] PASS")
		quit(0)
	else:
		push_error("[tests] FAIL: %d failure(s)" % failures)
		quit(1)

func _test_main_scene() -> void:
	var scene := load("res://scenes/main.tscn")
	_expect(scene is PackedScene, "main scene loads as PackedScene")

func _test_mobile_contract() -> void:
	var orientation := int(ProjectSettings.get_setting("display/window/handheld/orientation", -1))
	_expect(orientation == DisplayServer.SCREEN_SENSOR_LANDSCAPE, "mobile orientation is sensor landscape")
	_expect(FileAccess.file_exists("res://src/player/mobile_controls.gd"), "mobile controls exist")
	_expect(FileAccess.file_exists("res://src/player/production_avatar.gd"), "production avatar loader exists")
	_expect(FileAccess.file_exists("res://src/world/production_origin_runtime.gd"), "production origin runtime exists")
	var player_scene := load("res://scenes/player/player.tscn")
	_expect(player_scene is PackedScene, "player scene loads as PackedScene")

func _test_production_asset_contract() -> void:
	var manifest_file := FileAccess.open("res://data/assets/remote_assets.json", FileAccess.READ)
	_expect(manifest_file != null, "production asset manifest exists")
	if manifest_file == null:
		return
	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	_expect(parsed is Dictionary, "production asset manifest parses")
	if not (parsed is Dictionary):
		return
	var assets: Array = parsed.get("assets", [])
	_expect(assets.size() >= 3, "production manifest pins city, character and vehicle")
	for raw_asset in assets:
		if not (raw_asset is Dictionary):
			_expect(false, "asset manifest item is an object")
			continue
		var asset: Dictionary = raw_asset
		var path := "res://%s" % String(asset.get("path", ""))
		_expect(FileAccess.file_exists(path), "asset exists: %s" % path)
		if FileAccess.file_exists(path):
			var handle := FileAccess.open(path, FileAccess.READ)
			if handle != null:
				_expect(handle.get_length() >= 100_000, "asset is non-trivial: %s" % path)

func _test_vehicle_contract() -> void:
	_expect(FileAccess.file_exists("res://src/vehicles/driveable_vehicle.gd"), "driveable vehicle controller exists")
	var vehicle_scene := load("res://scenes/vehicles/driveable_sedan.tscn")
	_expect(vehicle_scene is PackedScene, "driveable sedan scene loads")
	if vehicle_scene is PackedScene:
		var vehicle := (vehicle_scene as PackedScene).instantiate()
		_expect(vehicle is VehicleBody3D, "driveable sedan root is VehicleBody3D")
		if vehicle is VehicleBody3D:
			var wheel_count := 0
			for child in vehicle.get_children():
				if child is VehicleWheel3D:
					wheel_count += 1
			_expect(wheel_count == 4, "driveable sedan has four physical wheels")
		vehicle.queue_free()

func _test_json(path: String, required_key: String) -> void:
	if not FileAccess.file_exists(path):
		_expect(false, "%s exists" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "%s parses as object" % path)
	if parsed is Dictionary:
		_expect(parsed.has(required_key), "%s contains '%s'" % [path, required_key])

func _test_mission_targets() -> void:
	var file := FileAccess.open("res://data/missions/prologue.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	for mission in parsed.get("missions", []):
		var stages: Dictionary = mission.get("stages", {})
		_expect(stages.has(mission.get("start_stage", "")), "mission start stage exists")
		for stage_id in stages:
			var stage: Dictionary = stages[stage_id]
			var next_stage := String(stage.get("next", ""))
			if not next_stage.is_empty() and next_stage != "__complete":
				_expect(stages.has(next_stage), "stage target %s exists" % next_stage)
			for choice in stage.get("choices", []):
				var target := String(choice.get("next", ""))
				if not target.is_empty() and target != "__complete":
					_expect(stages.has(target), "choice target %s exists" % target)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  OK  ", message)
	else:
		failures += 1
		push_error("  ERR " + message)
