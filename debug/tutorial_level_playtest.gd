extends Node2D

@onready var level: TutorialLevel = $World/TutorialLevel
@onready var player: Boat = $Player
@onready var pause_menu := $PauseMenu


func _ready() -> void:
	GameState.reset()
	GameState.pause_changed.connect(_on_pause_changed)
	level.setup(player)
	player.global_position = level.get_start_position()
	_on_pause_changed(GameState.is_paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameState.set_paused(not GameState.is_paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_reset"):
		get_viewport().set_input_as_handled()
		_reset_current_scene()


func _reset_current_scene() -> void:
	Engine.time_scale = 1.0
	GameState.set_paused(false)
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("Failed to reload tutorial playtest scene: %s" % error)


func _on_pause_changed(is_paused: bool) -> void:
	pause_menu.visible = is_paused
