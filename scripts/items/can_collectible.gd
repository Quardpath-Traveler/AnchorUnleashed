class_name CanCollectible
extends Area2D

signal collected(value: int)

@export var value: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("boats"):
		GameState.award_coin_pickup(value)
		AudioManager.play_coin_pickup()
		collected.emit(value)
		queue_free()
