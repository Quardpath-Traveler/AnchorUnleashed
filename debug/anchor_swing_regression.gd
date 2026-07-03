extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")
const HOOK_POINT_SCENE := preload("res://scenes/mechanics/HookPoint.tscn")

@export var hook_position: Vector2 = Vector2(640.0, 220.0)
@export var rope_length: float = 260.0
@export_range(5.0, 85.0, 1.0) var start_angle_degrees: float = 74.0
@export var frames_to_run: int = 120
@export var stall_distance_threshold: float = 8.0
@export var recovery_window_frames: int = 15
@export var recovery_distance_threshold: float = 4.0
@export var alignment_start_frame: int = 20
@export var min_alignment_speed: float = 80.0
@export var max_alignment_error_degrees: float = 24.0
@export var max_initial_rotation_step_degrees: float = 20.0
@export var min_alignment_samples: int = 20
@export var fail_on_stall: bool = false
@export var fail_on_alignment: bool = false
@export var fail_on_initial_rotation_snap: bool = false

var _boat: Boat
var _hook_point: HookPoint
var _initial_position: Vector2
var _pre_hook_rotation: float = 0.0
var _frame_index: int = 0
var _max_displacement: float = 0.0
var _max_speed: float = 0.0
var _max_alignment_error: float = 0.0
var _initial_rotation_step_degrees: float = 0.0
var _alignment_samples: int = 0
var _recovery_window_start_position: Vector2


func _ready() -> void:
	_spawn_test_world()
	call_deferred("_attach_anchor_at_turning_point")


func _physics_process(_delta: float) -> void:
	if _boat == null or not is_instance_valid(_boat):
		return
	if not _boat.anchor.is_hooked():
		return

	_frame_index += 1
	if _frame_index == frames_to_run - recovery_window_frames:
		_recovery_window_start_position = _boat.global_position

	var displacement := _boat.global_position.distance_to(_initial_position)
	_max_displacement = maxf(_max_displacement, displacement)
	_max_speed = maxf(_max_speed, _boat.linear_velocity.length())
	if _frame_index == 1:
		_initial_rotation_step_degrees = absf(rad_to_deg(wrapf(
			_boat.global_rotation - _pre_hook_rotation,
			-PI,
			PI
		)))
	_update_alignment_result()

	if _frame_index % 15 == 0 or _frame_index == 1:
		_boat.emit_posture_log()
		print("ANCHOR_SWING_TEST %s" % JSON.stringify({
			"frame": _frame_index,
			"position": _vector_to_log_data(_boat.global_position),
			"velocity": _vector_to_log_data(_boat.linear_velocity),
			"speed": snappedf(_boat.linear_velocity.length(), 0.001),
			"displacement": snappedf(displacement, 0.001),
			"initial_rotation_step_degrees": snappedf(_initial_rotation_step_degrees, 0.001),
			"max_alignment_error_degrees": snappedf(_max_alignment_error, 0.001),
			"anchor_hooked": _boat.anchor.is_hooked(),
		}))

	if _frame_index < frames_to_run:
		return

	var recovery_distance := _boat.global_position.distance_to(_recovery_window_start_position)
	var stalled := (
		_max_displacement < stall_distance_threshold
		or recovery_distance < recovery_distance_threshold
	)
	var alignment_failed := (
		_alignment_samples < min_alignment_samples
		or _max_alignment_error > max_alignment_error_degrees
	)
	var initial_rotation_snap_failed := (
		_initial_rotation_step_degrees > max_initial_rotation_step_degrees
	)
	print("ANCHOR_SWING_RESULT %s" % JSON.stringify({
		"frames": _frame_index,
		"max_displacement": snappedf(_max_displacement, 0.001),
		"max_speed": snappedf(_max_speed, 0.001),
		"recovery_distance": snappedf(recovery_distance, 0.001),
		"alignment_samples": _alignment_samples,
		"max_alignment_error_degrees": snappedf(_max_alignment_error, 0.001),
		"initial_rotation_step_degrees": snappedf(_initial_rotation_step_degrees, 0.001),
		"initial_rotation_snap_failed": initial_rotation_snap_failed,
		"alignment_failed": alignment_failed,
		"stalled": stalled,
	}))

	if (
		(fail_on_stall and stalled)
		or (fail_on_alignment and alignment_failed)
		or (fail_on_initial_rotation_snap and initial_rotation_snap_failed)
	):
		get_tree().quit(1)
	else:
		get_tree().quit()


func _spawn_test_world() -> void:
	_hook_point = HOOK_POINT_SCENE.instantiate() as HookPoint
	add_child(_hook_point)
	_hook_point.global_position = hook_position

	_boat = BOAT_SCENE.instantiate() as Boat
	add_child(_boat)
	_boat.posture_logging_enabled = false
	_boat.freeze = true
	_initial_position = hook_position + _get_start_rope_direction() * rope_length
	_boat.global_position = _initial_position
	_boat.linear_velocity = Vector2.ZERO
	_boat.angular_velocity = 0.0

	var camera := Camera2D.new()
	add_child(camera)
	camera.global_position = hook_position + Vector2(0.0, 130.0)
	camera.zoom = Vector2(0.75, 0.75)
	camera.enabled = true


func _attach_anchor_at_turning_point() -> void:
	_initial_position = hook_position + _get_start_rope_direction() * rope_length
	_boat.global_position = _initial_position
	_boat.linear_velocity = Vector2.ZERO
	_boat.angular_velocity = 0.0
	_pre_hook_rotation = _boat.global_rotation
	_boat.anchor.state = Anchor.State.FLYING
	_boat.anchor.is_ready = false
	_boat.anchor.attach_to(_hook_point)
	_boat.freeze = false


func _get_start_rope_direction() -> Vector2:
	var angle := deg_to_rad(start_angle_degrees)
	return Vector2(-sin(angle), cos(angle)).normalized()


func _update_alignment_result() -> void:
	if _frame_index < alignment_start_frame:
		return
	if _boat.linear_velocity.length() <= min_alignment_speed:
		return

	var posture := _boat.get_posture_log_data()
	var error_variant: Variant = posture.get("anchor_swing_alignment_error_degrees", null)
	if error_variant == null:
		return

	var error_degrees := float(error_variant)
	_alignment_samples += 1
	_max_alignment_error = maxf(_max_alignment_error, error_degrees)


func _vector_to_log_data(value: Vector2) -> Dictionary:
	return {
		"x": snappedf(value.x, 0.001),
		"y": snappedf(value.y, 0.001),
	}
