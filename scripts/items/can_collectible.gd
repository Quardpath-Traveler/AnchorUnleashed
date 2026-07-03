class_name CanCollectible
extends Area2D

signal collected(value: int)

@export var value: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("boats"):
		collected.emit(value)
		queue_free()
