extends Node


func _ready() -> void:
	EventBus.scene_transition_requested.connect(change_scene)
	EventBus.game_over_requested.connect(_on_game_over)


func change_scene(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Failed to change scene to %s: %s" % [scene_path, error])


func _on_game_over() -> void:
	Engine.time_scale = 1.0
	GameState.set_paused(false)
	change_scene("res://scenes/ui/ResultScreen.tscn")
