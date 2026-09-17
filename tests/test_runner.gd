extends SceneTree

var failures := 0

func _initialize() -> void:
	print("[tests] Last Shift headless smoke tests")
	_test_main_scene()
	_test_mobile_contract()
	_test_json("res://data/missions/prologue.json", "missions")
	_test_json("res://data/events/world_events.json", "events")
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
	_expect(FileAccess.file_exists("res://src/player/mobile_humanoid_avatar.gd"), "mobile humanoid avatar exists")
	var player_scene := load("res://scenes/player/player.tscn")
	_expect(player_scene is PackedScene, "player scene loads as PackedScene")

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
