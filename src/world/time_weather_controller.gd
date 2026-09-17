extends Node

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var real_seconds_per_game_day := 1800.0

var _sun: DirectionalLight3D
var _world_environment: WorldEnvironment
var _weather_id := "clear"
var _weather_timer := 110.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_sun = get_node_or_null(sun_path)
	_world_environment = get_node_or_null(environment_path)
	_rng.randomize()
	_update_visuals()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var minutes_per_second := 1440.0 / maxf(real_seconds_per_game_day, 60.0)
	WorldState.advance_minutes(delta * minutes_per_second)
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_roll_weather()
	_update_visuals()

func _roll_weather() -> void:
	_weather_timer = _rng.randf_range(120.0, 260.0)
	var roll := _rng.randf()
	var next_weather := "clear"
	if roll > 0.94:
		next_weather = "rain"
	elif roll > 0.82:
		next_weather = "haze"
	if next_weather != _weather_id:
		_weather_id = next_weather
		EventBus.weather_changed.emit(_weather_id)
		EventBus.show_toast("Weather: %s" % _weather_id.capitalize(), 2.2)

func _update_visuals() -> void:
	var hour := WorldState.get_hour_float()
	var daylight := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
	var dusk := 1.0 - absf(hour - 18.5) / 2.0 if hour > 16.5 and hour < 20.5 else 0.0
	dusk = clampf(dusk, 0.0, 1.0)

	if is_instance_valid(_sun):
		_sun.rotation_degrees.x = lerpf(-8.0, -72.0, daylight)
		_sun.rotation_degrees.y = fmod(hour * 15.0, 360.0)
		_sun.light_energy = lerpf(0.05, 1.18, daylight)
		_sun.light_color = Color(1.0, 0.57, 0.34).lerp(Color(1.0, 0.94, 0.82), daylight)

	if not is_instance_valid(_world_environment) or _world_environment.environment == null:
		return

	var environment := _world_environment.environment
	var night_color := Color(0.008, 0.014, 0.030)
	var day_color := Color(0.33, 0.47, 0.62)
	var color := night_color.lerp(day_color, daylight)
	if dusk > 0.0:
		color = color.lerp(Color(0.52, 0.19, 0.10), dusk * 0.45)
	if _weather_id == "haze":
		color = color.lerp(Color(0.35, 0.31, 0.25), 0.30)
	elif _weather_id == "rain":
		color = color.lerp(Color(0.08, 0.10, 0.13), 0.55)
	environment.background_color = color
	environment.ambient_light_color = color.lightened(0.25)
	environment.ambient_light_energy = lerpf(0.38, 0.80, daylight)
