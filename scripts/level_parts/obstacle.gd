class_name Obstacle
extends StaticBody2D

signal boat_hit(boat: Node2D)

@onready var hit_area: Area2D = %HitArea


func _ready() -> void:
	hit_area.body_entered.connect(_on_hit_area_body_entered)


func _on_hit_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("boats"):
		if body.has_method("lose_crew"):
			body.lose_crew()
		boat_hit.emit(body)
