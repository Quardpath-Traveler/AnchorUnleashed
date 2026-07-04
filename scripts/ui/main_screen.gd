extends CanvasLayer

@onready var start_button: Button = %StartButton


func _ready() -> void:
	start_button.pressed.connect(_start_game)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()


func _start_game() -> void:
	get_viewport().set_input_as_handled()
	EventBus.scene_transition_requested.emit("res://scenes/game/Game.tscn")
