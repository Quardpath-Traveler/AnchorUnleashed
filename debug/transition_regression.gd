extends Node2D


func _ready() -> void:
	print("[TransitionRegression] Ready. Press CONFIRM (Enter/LMB) to go to Game.tscn, DEBUG_RESET (R) to reload current scene.")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		print("[TransitionRegression] Requesting transition to Game.tscn")
		EventBus.scene_transition_requested.emit("res://scenes/game/Game.tscn")
	elif event.is_action_pressed("debug_reset"):
		print("[TransitionRegression] Requesting reload")
		SceneLoader.reload_scene()
