extends CanvasLayer

signal resume_requested


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%ResumeButton.pressed.connect(_on_resume_button_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("confirm"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _on_resume_button_pressed() -> void:
	resume_requested.emit()
