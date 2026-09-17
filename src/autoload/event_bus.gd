extends Node

signal setting_changed(key: String, value: Variant)
signal performance_changed(render_scale: float, pressure: float, tier: String)
signal world_action(action_id: String, payload: Dictionary)
signal interaction_prompt_changed(prompt: String, visible: bool)
signal dynamic_event_started(event_id: String, title: String, description: String)
signal dynamic_event_finished(event_id: String)
signal mission_started(mission_id: String, title: String)
signal mission_updated(mission_id: String, objective: String)
signal mission_completed(mission_id: String)
signal mission_choices_requested(mission_id: String, choices: Array)
signal toast(text: String, duration: float)
signal save_finished(slot: int)
signal load_finished(slot: int, ok: bool)
signal weather_changed(weather_id: String)

func show_toast(text: String, duration: float = 3.0) -> void:
	toast.emit(text, duration)
