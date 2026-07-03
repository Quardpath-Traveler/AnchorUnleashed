class_name LevelPrototypeSlope
extends Node2D

signal level_completed

@onready var start_marker: Marker2D = %StartMarker
@onready var finish_area: Area2D = %FinishArea


func _ready() -> void:
	finish_area.body_entered.connect(_on_finish_area_body_entered)


func get_start_position() -> Vector2:
	return start_marker.global_position


func _on_finish_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("boats"):
		level_completed.emit()
