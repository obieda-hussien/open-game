class_name ProductionAvatar
extends Node3D

const MODEL_PATH := "res://assets/external/last_shift_mechanic_v2.glb"
const FALLBACK_SCRIPT := preload("res://src/player/mobile_humanoid_avatar.gd")

var _model_root: Node3D
var _fallback: Node3D
var _animation_player: AnimationPlayer
var _last_animation := ""
var _crouch_blend := 0.0
var _lean := 0.0

func _ready() -> void:
	if not _load_production_model():
		_create_fallback()

func _load_production_model() -> bool:
	if not ResourceLoader.exists(MODEL_PATH):
		return false
	var resource := ResourceLoader.load(MODEL_PATH)
	if not (resource is PackedScene):
		push_warning("Production avatar GLB did not import as PackedScene: %s" % MODEL_PATH)
		return false

	var instance := (resource as PackedScene).instantiate()
	if not (instance is Node3D):
		instance.queue_free()
		return false

	_model_root = instance as Node3D
	_model_root.name = "MechanicModel"
	_model_root.position = Vector3.ZERO
	add_child(_model_root)
	_disable_embedded_cameras_and_lights(_model_root)
	_animation_player = _find_animation_player(_model_root)
	return true

func _create_fallback() -> void:
	_fallback = Node3D.new()
	_fallback.name = "FallbackHumanoid"
	_fallback.set_script(FALLBACK_SCRIPT)
	add_child(_fallback)

func set_motion_state(speed: float, sprinting: bool, crouching: bool, delta: float) -> void:
	if is_instance_valid(_fallback) and _fallback.has_method("set_motion_state"):
		_fallback.call("set_motion_state", speed, sprinting, crouching, delta)

	_crouch_blend = lerpf(_crouch_blend, 1.0 if crouching else 0.0, 1.0 - exp(-10.0 * delta))
	_lean = lerpf(_lean, clampf(speed / 8.5, 0.0, 1.0) * (0.055 if sprinting else 0.025), 1.0 - exp(-8.0 * delta))

	if is_instance_valid(_model_root):
		_model_root.position.y = -0.23 * _crouch_blend
		_model_root.rotation.x = lerpf(_model_root.rotation.x, _lean + 0.11 * _crouch_blend, 1.0 - exp(-9.0 * delta))

	if not is_instance_valid(_animation_player):
		return

	var wanted := "LocomotionWalk"
	if _animation_player.has_animation(wanted):
		if _last_animation != wanted or not _animation_player.is_playing():
			_animation_player.play(wanted, 0.16)
			_last_animation = wanted
		if speed < 0.08:
			_animation_player.speed_scale = 0.0
		else:
			_animation_player.speed_scale = clampf(speed / 4.35, 0.55, 1.75 if sprinting else 1.22)

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if is_instance_valid(found):
			return found
	return null

func _disable_embedded_cameras_and_lights(root: Node) -> void:
	if root is Camera3D:
		(root as Camera3D).current = false
	elif root is Light3D:
		(root as Light3D).visible = false
	for child in root.get_children():
		_disable_embedded_cameras_and_lights(child)
