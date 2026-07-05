extends CanvasLayer


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()


func _start_game() -> void:
	get_viewport().set_input_as_handled()
	LevelManager.start_new_game()
	EventBus.scene_transition_requested.emit("res://scenes/game/Game.tscn")
