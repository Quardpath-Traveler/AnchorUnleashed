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

	var previous_crew_count: int = body.crew_count
	body.gain_crew(rescue_value)
	if body.crew_count <= previous_crew_count:
		return

	_rescued = true
	GameState.award_rescue(rescue_value)
	var rescued_npc := get_parent()
	if rescued_npc != null:
		rescued_npc.queue_free()
	else:
		queue_free()
