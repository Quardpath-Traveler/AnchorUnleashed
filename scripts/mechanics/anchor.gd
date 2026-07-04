class_name Anchor
extends Node2D

signal aim_started
signal launched(target_position: Vector2)
signal hooked(hook_point: Node2D)
signal recalled

enum State { READY, AIMING, FLYING, HOOKED }

@export var max_length: float = 360.0
@export var launch_speed: float = 500.0
@export var launch_gravity_scale: float = 1.05
@export var rope_visual_segments: int = 8
@export var rope_slack_pixels: float = 32.0
@export var aim_indicator_length: float = 150.0
@export var aim_indicator_head_length: float = 18.0
@export var aim_indicator_head_width: float = 12.0
@export var debug_logging_enabled: bool = false
@export var debug_log_interval_seconds: float = 0.25
@export var anchor_log_prefix: String = "ANCHOR_DEBUG"

var is_ready: bool = true
var is_aiming: bool = false
var state: State = State.READY
var throw_origin_global: Vector2
var launch_velocity: Vector2
var launch_initial_velocity: Vector2
var launch_carrier_velocity: Vector2
var launch_elapsed_seconds: float = 0.0
var launch_target_global: Vector2
var rope_length: float = 0.0
var attached_hook_point: Node2D
var _debug_log_elapsed: float = 0.0

@onready var rope_line: Line2D = %RopeLine
@onready var head: Area2D = %Head
@onready var aim_direction_line: Line2D = %AimDirectionLine
@onready var aim_direction_head: Line2D = %AimDirectionHead


func _ready() -> void:
	head.position = Vector2.ZERO
	rope_line.visible = false
	_hide_aim_indicator()
	head.area_entered.connect(_on_head_area_entered)
	_reset_to_socket()


func _physics_process(delta: float) -> void:
	match state:
		State.AIMING:
			_update_rope_visual()
		State.FLYING:
			global_position = _get_parabolic_flight_position(delta)
			rope_length = minf(global_position.distance_to(throw_origin_global), max_length)
			if global_position.distance_to(throw_origin_global) >= max_length:
				recall()
				return
			_update_rope_visual()
		State.HOOKED:
			if not is_instance_valid(attached_hook_point):
				recall()
				return
			global_position = attached_hook_point.global_position
			_update_rope_visual()

	_update_debug_log(delta)


func start_aim() -> void:
	if state != State.READY:
		return

	throw_origin_global = _get_rope_start_global()
	state = State.AIMING
	is_aiming = true
	_update_aim_indicator(throw_origin_global + Vector2.RIGHT)
	aim_started.emit()


func launch(target_position: Vector2) -> void:
	if state != State.AIMING or not is_ready:
		return

	throw_origin_global = _get_rope_start_global()
	launch_target_global = target_position
	var direction := throw_origin_global.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	top_level = true
	global_position = throw_origin_global
	launch_carrier_velocity = _get_launch_carrier_velocity()
	launch_initial_velocity = _get_launch_initial_velocity(direction, launch_carrier_velocity)
	launch_velocity = launch_initial_velocity
	launch_elapsed_seconds = 0.0
	rope_length = 0.0
	_debug_log_elapsed = 0.0
	state = State.FLYING
	is_aiming = false
	is_ready = false
	_hide_aim_indicator()
	rope_line.visible = true
	_update_rope_visual()
	_emit_anchor_log_if_enabled(true)
	launched.emit(target_position)


func attach_to(hook_point: Node2D) -> void:
	if state != State.FLYING:
		return

	attached_hook_point = hook_point
	global_position = attached_hook_point.global_position
	rope_length = minf(_get_rope_start_global().distance_to(attached_hook_point.global_position), max_length)
	state = State.HOOKED
	_update_rope_visual()
	_emit_anchor_log_if_enabled(true)
	hooked.emit(hook_point)


func recall() -> void:
	if state == State.READY:
		return

	attached_hook_point = null
	state = State.READY
	is_aiming = false
	is_ready = true
	rope_line.visible = false
	_hide_aim_indicator()
	_reset_to_socket()
	_emit_anchor_log_if_enabled(true)
	recalled.emit()


func is_active() -> bool:
	return state == State.AIMING or state == State.FLYING or state == State.HOOKED


func is_hooked() -> bool:
	return state == State.HOOKED and is_instance_valid(attached_hook_point)


func get_rope_length() -> float:
	return rope_length


func get_hook_global_position() -> Vector2:
	if is_hooked():
		return attached_hook_point.global_position

	return global_position


func update_aim_target(target_position: Vector2) -> void:
	if state != State.AIMING:
		_hide_aim_indicator()
		return

	_update_aim_indicator(target_position)


func get_anchor_log_data() -> Dictionary:
	return {
		"time_msec": Time.get_ticks_msec(),
		"state": _get_state_name(),
		"is_ready": is_ready,
		"is_aiming": is_aiming,
		"global_position": _vector_to_log_data(global_position),
		"throw_origin_global": _vector_to_log_data(throw_origin_global),
		"launch_target_global": _vector_to_log_data(launch_target_global),
		"launch_velocity": _vector_to_log_data(launch_velocity),
		"launch_initial_velocity": _vector_to_log_data(launch_initial_velocity),
		"launch_carrier_velocity": _vector_to_log_data(launch_carrier_velocity),
		"launch_elapsed_seconds": snappedf(launch_elapsed_seconds, 0.001),
		"rope_length": snappedf(rope_length, 0.001),
		"max_length": snappedf(max_length, 0.001),
		"rope_point_count": rope_line.points.size(),
		"hooked": is_hooked(),
		"attached_hook_point_valid": is_instance_valid(attached_hook_point),
	}


func emit_anchor_log() -> void:
	print("%s %s" % [anchor_log_prefix, JSON.stringify(get_anchor_log_data())])


func _on_head_area_entered(area: Area2D) -> void:
	var hook_point := area.get_parent()
	if hook_point != null and hook_point.is_in_group("hook_points"):
		attach_to(hook_point)


func _get_rope_start_global() -> Vector2:
	var parent_node := get_parent()
	if parent_node is Node2D:
		return (parent_node as Node2D).global_position

	return throw_origin_global


func _get_parabolic_flight_position(delta: float) -> Vector2:
	launch_elapsed_seconds += delta
	launch_velocity = (
		launch_initial_velocity
		+ _get_gravity_direction() * _get_launch_gravity_acceleration() * launch_elapsed_seconds
	)

	return (
		throw_origin_global
		+ launch_initial_velocity * launch_elapsed_seconds
		+ 0.5 * _get_gravity_direction() * _get_launch_gravity_acceleration()
		* launch_elapsed_seconds * launch_elapsed_seconds
	)


func _get_launch_initial_velocity(direction: Vector2, carrier_velocity: Vector2) -> Vector2:
	return direction * launch_speed + carrier_velocity


func _get_launch_carrier_velocity() -> Vector2:
	var current_node := get_parent()
	while current_node != null:
		if current_node is RigidBody2D:
			return (current_node as RigidBody2D).linear_velocity
		current_node = current_node.get_parent()

	return Vector2.ZERO


func _get_gravity_direction() -> Vector2:
	var gravity_direction := ProjectSettings.get_setting("physics/2d/default_gravity_vector") as Vector2
	if gravity_direction.is_zero_approx():
		return Vector2.DOWN

	return gravity_direction.normalized()


func _get_launch_gravity_acceleration() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity")) * launch_gravity_scale


func _update_rope_visual() -> void:
	head.global_position = global_position
	rope_line.visible = is_active()
	rope_line.points = _build_slack_rope_points(_get_rope_start_global(), global_position)


func _update_aim_indicator(target_position: Vector2) -> void:
	var start_global := _get_rope_start_global()
	var direction := start_global.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	var clamped_length := minf(aim_indicator_length, max_length)
	var end_global := start_global + direction * clamped_length
	var start_local := to_local(start_global)
	var end_local := to_local(end_global)
	var direction_local := (end_local - start_local).normalized()
	var perpendicular_local := Vector2(-direction_local.y, direction_local.x)
	var head_base := end_local - direction_local * aim_indicator_head_length
	var head_half_width := aim_indicator_head_width * 0.5

	aim_direction_line.visible = true
	aim_direction_head.visible = true
	aim_direction_line.points = PackedVector2Array([
		start_local,
		end_local,
	])
	aim_direction_head.points = PackedVector2Array([
		head_base + perpendicular_local * head_half_width,
		end_local,
		head_base - perpendicular_local * head_half_width,
	])


func _hide_aim_indicator() -> void:
	aim_direction_line.visible = false
	aim_direction_head.visible = false
	aim_direction_line.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2.ZERO,
	])
	aim_direction_head.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2.ZERO,
		Vector2.ZERO,
	])


func _build_slack_rope_points(start_global: Vector2, end_global: Vector2) -> PackedVector2Array:
	var start_local := to_local(start_global)
	var end_local := to_local(end_global)
	var segment_count := maxi(rope_visual_segments, 2)
	var points := PackedVector2Array()

	if start_local.distance_to(end_local) <= 0.001:
		points.append(start_local)
		points.append(end_local)
		return points

	for index in range(segment_count + 1):
		var ratio := float(index) / float(segment_count)
		var point := start_local.lerp(end_local, ratio)
		point += _get_rope_slack_offset(ratio, start_local, end_local)
		points.append(point)

	return points


func _get_rope_slack_offset(ratio: float, start_local: Vector2, end_local: Vector2) -> Vector2:
	if ratio <= 0.0 or ratio >= 1.0:
		return Vector2.ZERO

	var gravity_local := global_transform.basis_xform_inv(_get_gravity_direction()).normalized()
	var rope_distance := start_local.distance_to(end_local)
	var distance_scale := clampf(rope_distance / maxf(max_length, 1.0), 0.2, 1.0)
	return gravity_local * rope_slack_pixels * sin(PI * ratio) * distance_scale


func _reset_to_socket() -> void:
	top_level = false
	position = Vector2.ZERO
	rotation = 0.0
	rope_length = 0.0
	launch_elapsed_seconds = 0.0
	launch_velocity = Vector2.ZERO
	launch_initial_velocity = Vector2.ZERO
	launch_carrier_velocity = Vector2.ZERO
	head.position = Vector2.ZERO
	_hide_aim_indicator()
	rope_line.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2.ZERO,
	])


func _update_debug_log(delta: float) -> void:
	if not debug_logging_enabled:
		return

	_debug_log_elapsed += delta
	if _debug_log_elapsed < debug_log_interval_seconds:
		return

	_debug_log_elapsed = 0.0
	emit_anchor_log()


func _emit_anchor_log_if_enabled(force: bool = false) -> void:
	if not debug_logging_enabled:
		return
	if not force and _debug_log_elapsed < debug_log_interval_seconds:
		return

	_debug_log_elapsed = 0.0
	emit_anchor_log()


func _get_state_name() -> String:
	match state:
		State.READY:
			return "READY"
		State.AIMING:
			return "AIMING"
		State.FLYING:
			return "FLYING"
		State.HOOKED:
			return "HOOKED"

	return "UNKNOWN"


func _vector_to_log_data(value: Vector2) -> Dictionary:
	return {
		"x": snappedf(value.x, 0.001),
		"y": snappedf(value.y, 0.001),
	}
