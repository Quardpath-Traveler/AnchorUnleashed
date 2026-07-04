class_name TutorialTrigger
extends Area2D

@export_multiline var prompt_text: String = ""
@export var one_shot: bool = true
@export_range(0.0, 10.0, 0.1) var auto_hide_seconds: float = 0.0

var has_triggered: bool = false


func can_trigger(body: Node2D) -> bool:
	if one_shot and has_triggered:
		return false
	return body.is_in_group("boats")


func mark_triggered() -> void:
	has_triggered = true
