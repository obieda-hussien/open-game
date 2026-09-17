extends Node

@export var event_data_path := "res://data/events/world_events.json"
@export var tick_seconds := 4.0

var _events: Array = []
var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()
var _last_trigger_minute: Dictionary = {}

func _ready() -> void:
	_rng.randomize()
	_load_events()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_elapsed += delta
	if _elapsed < tick_seconds:
		return
	_elapsed = 0.0
	_try_trigger_event()

func _load_events() -> void:
	if not FileAccess.file_exists(event_data_path):
		push_warning("Dynamic event data missing: %s" % event_data_path)
		return
	var file := FileAccess.open(event_data_path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_events = parsed.get("events", [])

func _try_trigger_event() -> void:
	if _events.is_empty():
		return
	var candidates: Array = []
	var total_weight := 0.0

	for raw_event in _events:
		if not (raw_event is Dictionary):
			continue
		var event: Dictionary = raw_event
		if not _eligible(event):
			continue
		var probability_per_minute := float(event.get("chance_per_minute", 0.05))
		var simulated_minutes := tick_seconds * 0.16
		if _rng.randf() > probability_per_minute * simulated_minutes:
			continue
		var weight := maxf(0.01, float(event.get("weight", 1.0)))
		candidates.append({"event": event, "weight": weight})
		total_weight += weight

	if candidates.is_empty():
		return

	var pick := _rng.randf_range(0.0, total_weight)
	var running := 0.0
	for candidate in candidates:
		running += float(candidate["weight"])
		if pick <= running:
			_trigger(candidate["event"])
			return

func _eligible(event: Dictionary) -> bool:
	if WorldState.reputation < int(event.get("min_reputation", -9999)):
		return false
	if WorldState.chapter < int(event.get("min_chapter", 1)):
		return false

	var hour := WorldState.get_hour_float()
	var start_hour := float(event.get("start_hour", 0.0))
	var end_hour := float(event.get("end_hour", 24.0))
	if not _hour_in_window(hour, start_hour, end_hour):
		return false

	var id := String(event.get("id", ""))
	var cooldown := float(event.get("cooldown_minutes", 90.0))
	if _last_trigger_minute.has(id):
		var last_value := float(_last_trigger_minute[id])
		var current_absolute := float((WorldState.day - 1) * 1440) + WorldState.game_minutes
		if current_absolute - last_value < cooldown:
			return false

	for required_flag in event.get("required_flags", []):
		if not bool(WorldState.get_flag(String(required_flag), false)):
			return false
	for blocked_flag in event.get("blocked_flags", []):
		if bool(WorldState.get_flag(String(blocked_flag), false)):
			return false
	return true

func _hour_in_window(hour: float, start_hour: float, end_hour: float) -> bool:
	if start_hour <= end_hour:
		return hour >= start_hour and hour <= end_hour
	return hour >= start_hour or hour <= end_hour

func _trigger(event: Dictionary) -> void:
	var id := String(event.get("id", "unknown"))
	var current_absolute := float((WorldState.day - 1) * 1440) + WorldState.game_minutes
	_last_trigger_minute[id] = current_absolute
	WorldState.active_world_events[id] = current_absolute
	EventBus.dynamic_event_started.emit(
		id,
		String(event.get("title", id)),
		String(event.get("description", ""))
	)
	EventBus.show_toast(String(event.get("title", "Something happened nearby")), 3.4)
