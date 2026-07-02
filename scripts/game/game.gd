extends Node2D

@onready var pause_menu := $PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset()
	GameState.pause_changed.connect(_on_pause_changed)
	pause_menu.resume_requested.connect(_on_resume_requested)
	_on_pause_changed(GameState.is_paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameState.set_paused(not GameState.is_paused)
		get_viewport().set_input_as_handled()


func _on_pause_changed(is_paused: bool) -> void:
	pause_menu.visible = is_paused


func _on_resume_requested() -> void:
	GameState.set_paused(false)
