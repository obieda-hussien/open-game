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
		_sun.rotation_degrees.x = lerpf(-8.0, -68.0, daylight)
		_sun.rotation_degrees.y = fmod(hour * 15.0 + 18.0, 360.0)
		_sun.light_energy = lerpf(0.035, 1.08, daylight)
		_sun.light_color = Color(1.0, 0.52, 0.30).lerp(Color(1.0, 0.94, 0.82), daylight)

	if not is_instance_valid(_world_environment) or _world_environment.environment == null:
		return

	var environment := _world_environment.environment
	var night_top := Color(0.008, 0.014, 0.033)
	var day_top := Color(0.19, 0.37, 0.58)
	var horizon_night := Color(0.035, 0.045, 0.075)
	var horizon_day := Color(0.66, 0.73, 0.72)
	var top_color := night_top.lerp(day_top, daylight)
	var horizon_color := horizon_night.lerp(horizon_day, daylight)

	if dusk > 0.0:
		horizon_color = horizon_color.lerp(Color(0.88, 0.34, 0.12), dusk * 0.62)
		top_color = top_color.lerp(Color(0.24, 0.18, 0.25), dusk * 0.22)
	if _weather_id == "haze":
		horizon_color = horizon_color.lerp(Color(0.50, 0.45, 0.37), 0.42)
	elif _weather_id == "rain":
		top_color = top_color.lerp(Color(0.075, 0.095, 0.12), 0.62)
		horizon_color = horizon_color.lerp(Color(0.18, 0.20, 0.21), 0.60)

	if environment.sky != null and environment.sky.sky_material is ProceduralSkyMaterial:
		var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
		sky_material.sky_top_color = top_color
		sky_material.sky_horizon_color = horizon_color
		sky_material.ground_bottom_color = Color(0.055, 0.050, 0.043).lerp(Color(0.26, 0.23, 0.18), daylight)
		sky_material.ground_horizon_color = horizon_color.darkened(0.24)

	environment.background_color = top_color
	environment.ambient_light_color = horizon_color.lightened(0.12)
	environment.ambient_light_energy = lerpf(0.34, 0.68, daylight)
	environment.fog_light_color = horizon_color
	environment.fog_density = 0.0042 if _weather_id == "rain" else (0.0030 if _weather_id == "haze" else 0.00115)
