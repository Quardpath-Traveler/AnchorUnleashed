class_name NPCRescue
extends Area2D


@export var rescue_value: int = 1

var _rescued: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _rescued:
		return
	if not body.is_in_group("boats"):
		return
	if not is_instance_valid(body):
		return
	if not body.has_method("gain_crew"):
		return

	_rescued = true
	body.gain_crew(rescue_value)
	var rescued_npc := get_parent()
	if rescued_npc != null:
		rescued_npc.queue_free()
	else:
		queue_free()
