class_name WaveChaser
extends Area2D

@export var chase_speed: float = 90.0
@export var max_distance_from_target: float = 520.0
@export var target_path: NodePath

var target: Node2D


func _ready() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path)


func _physics_process(delta: float) -> void:
	if target == null:
		return

	var next_x := position.x + chase_speed * delta
	position.x = min(next_x, target.position.x - max_distance_from_target)
