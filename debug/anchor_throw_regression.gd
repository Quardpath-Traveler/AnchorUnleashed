extends Node2D

const ANCHOR_SCENE := preload("res://scenes/mechanics/Anchor.tscn")

@export var target_offset: Vector2 = Vector2(380.0, -180.0)
@export var frames_to_sample: int = 24
@export var min_arc_deviation: float = 18.0
@export var min_apex_recovery: float = 6.0
@export var min_upward_travel: float = 28.0
@export var min_chain_points: int = 5
@export var min_chain_slack: float = 6.0
@export var max_sampled_speed: float = 980.0
@export var fail_on_regression: bool = false

var _anchor: Anchor
var _samples: Array[Vector2] = []
var _frame_index: int = 0
var _max_sampled_speed: float = 0.0


func _ready() -> void:
	var socket := Marker2D.new()
	add_child(socket)
	socket.global_position = Vector2(120.0, 260.0)

	_anchor = ANCHOR_SCENE.instantiate() as Anchor
	socket.add_child(_anchor)
	_anchor.max_length = 720.0
	_anchor.start_aim()
	_anchor.launch(socket.global_position + target_offset)
	_samples.append(_anchor.global_position)


func _physics_process(_delta: float) -> void:
	if _anchor == null or not is_instance_valid(_anchor):
		return

	if not _anchor.is_active():
		_finish(true)
		return

	_frame_index += 1
	_samples.append(_anchor.global_position)
	_max_sampled_speed = maxf(_max_sampled_speed, _anchor.launch_velocity.length())

	if _frame_index >= frames_to_sample:
		_finish(false)


func _finish(recalled_early: bool) -> void:
	set_physics_process(false)

	var rope_line := _anchor.get_node("RopeLine") as Line2D
	var arc_deviation := _get_max_line_deviation(_samples)
	var has_parabolic_apex := _has_parabolic_apex(_samples)
	var upward_travel := _get_max_upward_travel(_samples)
	var chain_point_count := rope_line.points.size()
	var chain_slack := _get_max_gravity_slack(rope_line.points)
	var log_has_required_fields := false

	if _anchor.has_method("get_anchor_log_data") and _anchor.has_method("emit_anchor_log"):
		var log_data: Dictionary = _anchor.get_anchor_log_data()
		log_has_required_fields = (
			log_data.has("state")
			and log_data.has("global_position")
			and log_data.has("launch_velocity")
			and log_data.has("launch_elapsed_seconds")
			and log_data.has("rope_length")
			and log_data.has("rope_point_count")
		)
		_anchor.emit_anchor_log()

	var failed := (
		recalled_early
		or arc_deviation < min_arc_deviation
		or not has_parabolic_apex
		or upward_travel < min_upward_travel
		or chain_point_count < min_chain_points
		or chain_slack < min_chain_slack
		or _max_sampled_speed > max_sampled_speed
		or not log_has_required_fields
	)

	print("ANCHOR_THROW_RESULT %s" % JSON.stringify({
		"frames": _frame_index,
		"recalled_early": recalled_early,
		"arc_deviation": snappedf(arc_deviation, 0.001),
		"has_parabolic_apex": has_parabolic_apex,
		"upward_travel": snappedf(upward_travel, 0.001),
		"chain_point_count": chain_point_count,
		"chain_slack": snappedf(chain_slack, 0.001),
		"max_sampled_speed": snappedf(_max_sampled_speed, 0.001),
		"log_has_required_fields": log_has_required_fields,
		"failed": failed,
	}))

	if fail_on_regression and failed:
		get_tree().quit(1)
	else:
		get_tree().quit()


func _get_max_line_deviation(points: Array[Vector2]) -> float:
	if points.size() < 3:
		return 0.0

	return _get_max_deviation_from_line(points, points.front(), points.back())


func _has_parabolic_apex(points: Array[Vector2]) -> bool:
	if points.size() < 5:
		return false

	var apex_index := 0
	var first_point: Vector2 = points[0]
	var last_point: Vector2 = points[points.size() - 1]
	var apex_y := first_point.y
	for index in range(points.size()):
		if points[index].y < apex_y:
			apex_y = points[index].y
			apex_index = index

	if apex_index <= 0 or apex_index >= points.size() - 1:
		return false

	var start_to_apex := first_point.y - apex_y
	var end_to_apex := last_point.y - apex_y
	return start_to_apex >= min_apex_recovery and end_to_apex >= min_apex_recovery


func _get_max_upward_travel(points: Array[Vector2]) -> float:
	if points.size() < 2:
		return 0.0

	var start_y := points[0].y
	var min_y := start_y
	for point in points:
		min_y = minf(min_y, point.y)

	return start_y - min_y


func _get_max_gravity_slack(points: PackedVector2Array) -> float:
	if points.size() < 3:
		return 0.0

	var gravity_local := _anchor.global_transform.basis_xform_inv(Vector2.DOWN).normalized()
	var start := points[0]
	var end := points[points.size() - 1]
	var max_slack := 0.0

	for index in range(1, points.size() - 1):
		var ratio := float(index) / float(points.size() - 1)
		var straight_point := start.lerp(end, ratio)
		var gravity_slack := (points[index] - straight_point).dot(gravity_local)
		max_slack = maxf(max_slack, gravity_slack)

	return max_slack


func _get_max_deviation_from_line(
	points: Array[Vector2],
	start: Vector2,
	end: Vector2
) -> float:
	var segment := end - start
	var segment_length := segment.length()
	if is_zero_approx(segment_length):
		return 0.0

	var max_deviation := 0.0
	for point in points:
		var deviation := absf(segment.cross(point - start)) / segment_length
		max_deviation = maxf(max_deviation, deviation)

	return max_deviation
