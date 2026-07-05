class_name TutorialTrigger
extends Area2D

@export var one_shot: bool = true

var has_triggered: bool = false
@onready var prompt_sprite: Sprite2D = $PromptSprite


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if prompt_sprite:
		prompt_sprite.visible = false


func can_trigger(body: Node2D) -> bool:
	if one_shot and has_triggered:
		return false
	return body.is_in_group("boats")


func mark_triggered() -> void:
	has_triggered = true


func _on_body_entered(body: Node2D) -> void:
	if not can_trigger(body):
		return

	mark_triggered()
	_show_prompt()


func _show_prompt() -> void:
	if prompt_sprite:
		prompt_sprite.visible = true
