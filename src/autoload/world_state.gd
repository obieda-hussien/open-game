extends Node

var day: int = 1
var game_minutes: float = 20.5 * 60.0
var cash: int = 420
var reputation: int = 0
var chapter: int = 1
var flags: Dictionary = {}
var relationships: Dictionary = {}
var active_world_events: Dictionary = {}
var performance_pressure: float = 0.0

func advance_minutes(amount: float) -> void:
	game_minutes += amount
	while game_minutes >= 1440.0:
		game_minutes -= 1440.0
		day += 1

func get_hour_float() -> float:
	return game_minutes / 60.0

func get_clock_text() -> String:
	var total := int(game_minutes) % 1440
	var hour := total / 60
	var minute := total % 60
	return "%02d:%02d" % [hour, minute]

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value

func get_flag(key: String, fallback: Variant = false) -> Variant:
	return flags.get(key, fallback)

func change_cash(amount: int) -> void:
	cash += amount

func change_reputation(amount: int) -> void:
	reputation += amount

func serialize_state() -> Dictionary:
	return {
		"day": day,
		"game_minutes": game_minutes,
		"cash": cash,
		"reputation": reputation,
		"chapter": chapter,
		"flags": flags.duplicate(true),
		"relationships": relationships.duplicate(true)
	}

func load_state(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	game_minutes = float(data.get("game_minutes", 20.5 * 60.0))
	cash = int(data.get("cash", 420))
	reputation = int(data.get("reputation", 0))
	chapter = int(data.get("chapter", 1))
	flags = data.get("flags", {}).duplicate(true)
	relationships = data.get("relationships", {}).duplicate(true)
