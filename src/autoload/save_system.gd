extends Node

const SAVE_VERSION := 1
const SLOT_PATTERN := "save_%02d.json"

func save_slot(slot: int = 0) -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"world": WorldState.serialize_state(),
		"missions": MissionManager.serialize_state()
	}
	var json := JSON.stringify(payload, "\t", false)
	var filename := SLOT_PATTERN % slot
	var temp_filename := "%s.tmp" % filename
	var temp_path := "user://%s" % temp_filename

	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open temporary save file.")
		return false
	file.store_string(json)
	file.flush()
	file.close()

	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists(filename):
		dir.remove(filename)
	var err := dir.rename(temp_filename, filename)
	if err != OK:
		push_error("Could not commit save file: %s" % error_string(err))
		return false

	EventBus.save_finished.emit(slot)
	return true

func load_slot(slot: int = 0) -> bool:
	var path := "user://%s" % (SLOT_PATTERN % slot)
	if not FileAccess.file_exists(path):
		EventBus.load_finished.emit(slot, false)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		EventBus.load_finished.emit(slot, false)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		EventBus.load_finished.emit(slot, false)
		return false
	var data: Dictionary = parsed
	if int(data.get("version", -1)) > SAVE_VERSION:
		push_warning("Save is newer than this build.")
		EventBus.load_finished.emit(slot, false)
		return false

	WorldState.load_state(data.get("world", {}))
	MissionManager.load_state(data.get("missions", {}))
	EventBus.load_finished.emit(slot, true)
	return true

func has_slot(slot: int = 0) -> bool:
	return FileAccess.file_exists("user://%s" % (SLOT_PATTERN % slot))
