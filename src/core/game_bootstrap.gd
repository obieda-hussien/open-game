extends Node3D

@export var autosave_seconds := 75.0

var _autosave_elapsed := 0.0

func _enter_tree() -> void:
	_ensure_input_map()

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	if SaveSystem.has_slot(0):
		SaveSystem.load_slot(0)
	if MissionManager.active.is_empty() and MissionManager.completed.is_empty():
		MissionManager.start_mission("prologue_first_shift")
	EventBus.show_toast("First shift started. Keep the garage alive.", 4.0)

func _process(delta: float) -> void:
	_autosave_elapsed += delta
	if _autosave_elapsed >= autosave_seconds:
		_autosave_elapsed = 0.0
		SaveSystem.save_slot(0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveSystem.save_slot(0)

func _ensure_input_map() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("crouch", KEY_C)
	_add_key_action("interact", KEY_E)
	_add_key_action("pause", KEY_ESCAPE)

func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.18)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	InputMap.action_add_event(action, key)
