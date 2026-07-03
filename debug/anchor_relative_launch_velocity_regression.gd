extends Node2D

const ANCHOR_SCENE := preload("res://scenes/mechanics/Anchor.tscn")

@export var boat_velocity: Vector2 = Vector2(240.0, 0.0)
@export var target_offset: Vector2 = Vector2(380.0, 0.0)
@export var velocity_tolerance: float = 0.01
@export var fail_on_regression: bool = true


func _ready() -> void:
	var boat := RigidBody2D.new()
	add_child(boat)
	boat.global_position = Vector2(120.0, 260.0)
	boat.linear_velocity = boat_velocity

	var socket := Marker2D.new()
	boat.add_child(socket)
	socket.global_position = boat.global_position

	var anchor: Variant = ANCHOR_SCENE.instantiate()
	socket.add_child(anchor as Node)
	anchor.call("start_aim")
	anchor.call("launch", socket.global_position + target_offset)

	var relative_velocity: Vector2 = target_offset.normalized() * float(anchor.get("launch_speed"))
	var expected_velocity: Vector2 = relative_velocity + boat_velocity
	var launch_initial_velocity := anchor.get("launch_initial_velocity") as Vector2
	var velocity_error := launch_initial_velocity.distance_to(expected_velocity)
	var failed := velocity_error > velocity_tolerance

	print("ANCHOR_RELATIVE_LAUNCH_RESULT %s" % JSON.stringify({
		"boat_velocity": _vector_to_log_data(boat_velocity),
		"relative_velocity": _vector_to_log_data(relative_velocity),
		"launch_initial_velocity": _vector_to_log_data(launch_initial_velocity),
		"expected_velocity": _vector_to_log_data(expected_velocity),
		"velocity_error": snappedf(velocity_error, 0.001),
		"failed": failed,
	}))

	if fail_on_regression and failed:
		get_tree().quit(1)
	else:
		get_tree().quit()


func _vector_to_log_data(value: Vector2) -> Dictionary:
	return {
		"x": snappedf(value.x, 0.001),
		"y": snappedf(value.y, 0.001),
	}
