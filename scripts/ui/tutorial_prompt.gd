class_name TutorialPrompt
extends CanvasLayer

@onready var label: Label = %PromptLabel


func show_prompt(text: String) -> void:
	label.text = text
	visible = true


func hide_prompt() -> void:
	visible = false
