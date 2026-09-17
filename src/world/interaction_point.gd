class_name InteractionPoint
extends Node3D

var action_id := ""
var prompt := "Interact"
var metadata: Dictionary = {}
var enabled := true

func configure(id: String, text: String, data: Dictionary = {}) -> InteractionPoint:
	action_id = id
	prompt = text
	metadata = data.duplicate(true)
	return self

func _ready() -> void:
	add_to_group("interactables")

func interact(actor: Node) -> void:
	if not enabled:
		return
	var payload := metadata.duplicate(true)
	payload["actor_path"] = String(actor.get_path())
	payload["world_position"] = {
		"x": global_position.x,
		"y": global_position.y,
		"z": global_position.z
	}
	EventBus.world_action.emit(action_id, payload)
	EventBus.show_toast(prompt, 1.8)
