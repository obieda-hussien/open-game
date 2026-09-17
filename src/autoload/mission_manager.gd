extends Node

const MISSIONS_PATH := "res://data/missions/prologue.json"

var definitions: Dictionary = {}
var active: Dictionary = {}
var completed: Dictionary = {}

func _ready() -> void:
	_load_definitions()
	EventBus.world_action.connect(_on_world_action)

func _load_definitions() -> void:
	definitions.clear()
	if not FileAccess.file_exists(MISSIONS_PATH):
		push_error("Mission data missing: %s" % MISSIONS_PATH)
		return
	var file := FileAccess.open(MISSIONS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Mission data is invalid JSON.")
		return
	for mission in parsed.get("missions", []):
		if mission is Dictionary and mission.has("id"):
			definitions[String(mission["id"])] = mission

func start_mission(mission_id: String) -> bool:
	if not definitions.has(mission_id) or active.has(mission_id) or completed.has(mission_id):
		return false
	var definition: Dictionary = definitions[mission_id]
	var start_stage := String(definition.get("start_stage", ""))
	if start_stage.is_empty():
		return false
	active[mission_id] = {"stage": start_stage}
	EventBus.mission_started.emit(mission_id, String(definition.get("title", mission_id)))
	_emit_current_stage(mission_id)
	return true

func choose(mission_id: String, choice_id: String) -> void:
	if not active.has(mission_id):
		return
	var stage := _current_stage_definition(mission_id)
	for raw_choice in stage.get("choices", []):
		if not (raw_choice is Dictionary):
			continue
		var choice: Dictionary = raw_choice
		if String(choice.get("id", "")) != choice_id:
			continue
		for key in choice.get("set_flags", {}):
			WorldState.set_flag(String(key), choice["set_flags"][key])
		var reputation_delta := int(choice.get("reputation", 0))
		var cash_delta := int(choice.get("cash", 0))
		if reputation_delta != 0:
			WorldState.change_reputation(reputation_delta)
		if cash_delta != 0:
			WorldState.change_cash(cash_delta)
		_advance(mission_id, String(choice.get("next", "")))
		return

func get_primary_objective() -> String:
	for mission_id in active:
		var stage := _current_stage_definition(String(mission_id))
		return String(stage.get("objective", ""))
	return "Explore the district."

func serialize_state() -> Dictionary:
	return {
		"active": active.duplicate(true),
		"completed": completed.duplicate(true)
	}

func load_state(data: Dictionary) -> void:
	active = data.get("active", {}).duplicate(true)
	completed = data.get("completed", {}).duplicate(true)
	for mission_id in active:
		_emit_current_stage(String(mission_id))

func _on_world_action(action_id: String, payload: Dictionary) -> void:
	for mission_id_variant in active.keys():
		var mission_id := String(mission_id_variant)
		var stage := _current_stage_definition(mission_id)
		if String(stage.get("complete_on", "")) == action_id:
			for key in stage.get("set_flags", {}):
				WorldState.set_flag(String(key), stage["set_flags"][key])
			_advance(mission_id, String(stage.get("next", "")))
			break

func _current_stage_definition(mission_id: String) -> Dictionary:
	if not active.has(mission_id) or not definitions.has(mission_id):
		return {}
	var stage_id := String(active[mission_id].get("stage", ""))
	return definitions[mission_id].get("stages", {}).get(stage_id, {})

func _advance(mission_id: String, next_stage: String) -> void:
	if next_stage.is_empty() or next_stage == "__complete":
		_complete(mission_id)
		return
	active[mission_id]["stage"] = next_stage
	_emit_current_stage(mission_id)

func _emit_current_stage(mission_id: String) -> void:
	var stage := _current_stage_definition(mission_id)
	if stage.is_empty():
		push_warning("Mission %s has an invalid stage." % mission_id)
		return
	if bool(stage.get("terminal", false)):
		_complete(mission_id)
		return
	EventBus.mission_updated.emit(mission_id, String(stage.get("objective", "")))
	var choices: Array = stage.get("choices", [])
	if not choices.is_empty():
		EventBus.mission_choices_requested.emit(mission_id, choices)

func _complete(mission_id: String) -> void:
	if not active.has(mission_id):
		return
	active.erase(mission_id)
	completed[mission_id] = {
		"day": WorldState.day,
		"time": WorldState.game_minutes
	}
	EventBus.mission_completed.emit(mission_id)
	EventBus.show_toast("Mission complete", 3.0)
