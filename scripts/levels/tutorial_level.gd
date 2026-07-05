class_name TutorialLevel
extends Node2D

signal level_completed

var player: Node2D
@onready var start_marker: Marker2D = %StartMarker
@onready var finish_area: Area2D = %FinishArea
@onready var wave_chaser: WaveChaser = %WaveChaser


func _ready() -> void:
	finish_area.body_entered.connect(_on_finish_area_body_entered)


func setup(active_player: Node2D) -> void:
	player = active_player
	wave_chaser.target = active_player


func get_start_position() -> Vector2:
	return start_marker.global_position


func _on_finish_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("boats"):
		level_completed.emit()
