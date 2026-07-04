extends Node2D

const DEBUG_SCENE := preload("res://debug/BoatRotationDebug.tscn")

enum Phase {
	DISABLE_LOCK,
	HOLD_D_UNLOCKED,
	ASSERT_FALL,
	ASSERT_RESET,
	ASSERT_LOCK,
	HOLD_D_LOCKED,
	ASSERT_LOCKED_ROTATION,
	ASSERT_TORQUE,
	HOLD_D_HIGH_TORQUE,
	ASSERT_TORQUE_VELOCITY,
	DONE,
}

@export var hold_d_unlocked_seconds: float = 2.0
@export var hold_d_locked_seconds: float = 1.0
@export var hold_d_high_torque_seconds: float = 2.0
@export var position_tolerance: float = 0.05
@export var locked_position_tolerance: float = 1.0
@export var rotation_tolerance: float = 0.05
@export var angular_velocity_tolerance: float = 0.05
@export var fall_distance_threshold: float = 50.0

var _debug: BoatRotationDebug
var _boat: Boat
var _phase: Phase = Phase.DISABLE_LOCK
var _phase_timer: float = 0.0
var _settle_frames: int = 1
var _initial_position: Vector2
var _initial_rotation: float
var _initial_torque: float
var _expected_torque: float
var _max_angular_velocity_initial: float = 0.0
var _max_angular_velocity_boosted: float = 0.0
var _failures: Array[String] = []
var _exit_code: int = 0


func _ready() -> void:
	_debug = DEBUG_SCENE.instantiate() as BoatRotationDebug
	add_child(_debug)

	_boat = _find_boat()
	if _boat == null or not is_instance_valid(_boat):
		_fail("Boat did not spawn")
		_finish()
		return

	_initial_position = _boat.global_position
	_initial_rotation = _boat.global_rotation
	_initial_torque = _boat.airborne_rotation_torque
	_expected_torque = _initial_torque

	if not _debug.position_locked:
		_fail("Position lock should start ON (default)")

	_press_key(KEY_L)
	_release_key(KEY_L)


func _physics_process(delta: float) -> void:
	_phase_timer += delta

	if _settle_frames > 0:
		_settle_frames -= 1
		if _settle_frames > 0:
			return

	match _phase:
		Phase.DISABLE_LOCK:
			if _debug.position_locked:
				_fail("L did not disable position_locked")
			_start_phase(Phase.HOLD_D_UNLOCKED, 1)
			_press_key(KEY_D)
			return

		Phase.HOLD_D_UNLOCKED:
			_max_angular_velocity_initial = maxf(_max_angular_velocity_initial, _boat.angular_velocity)
			if _phase_timer < hold_d_unlocked_seconds:
				return
			_release_key(KEY_D)
			_start_phase(Phase.ASSERT_FALL, 1)
			return

		Phase.ASSERT_FALL:
			if not (_boat.global_position.y > _initial_position.y + fall_distance_threshold):
				_fail("Boat did not fall while unlocked (y delta %f)" % (_boat.global_position.y - _initial_position.y))
			if not (_max_angular_velocity_initial > 0.0):
				_fail("Boat did not rotate while unlocked (max angular velocity %f)" % _max_angular_velocity_initial)
			_press_key(KEY_R)
			_release_key(KEY_R)
			_start_phase(Phase.ASSERT_RESET, 1)
			return

		Phase.ASSERT_RESET:
			_assert_reset()
			_press_key(KEY_L)
			_release_key(KEY_L)
			_start_phase(Phase.ASSERT_LOCK, 1)
			return

		Phase.ASSERT_LOCK:
			if not _debug.position_locked:
				_fail("L did not re-enable position_locked")
			_press_key(KEY_D)
			_start_phase(Phase.HOLD_D_LOCKED, 1)
			return

		Phase.HOLD_D_LOCKED:
			if _phase_timer < hold_d_locked_seconds:
				return
			_release_key(KEY_D)
			_start_phase(Phase.ASSERT_LOCKED_ROTATION, 1)
			return

		Phase.ASSERT_LOCKED_ROTATION:
			if _boat.global_position.distance_to(_initial_position) > locked_position_tolerance:
				_fail("Boat moved while position lock was enabled (position %v)" % _boat.global_position)
			if not (absf(_boat.angular_velocity) > angular_velocity_tolerance):
				_fail("Boat did not rotate in place while locked (angular velocity %f)" % _boat.angular_velocity)
			for _i in range(3):
				_press_key(KEY_PAGEUP)
				_release_key(KEY_PAGEUP)
				_expected_torque += _debug.rotation_torque_step
			_start_phase(Phase.ASSERT_TORQUE, 1)
			return

		Phase.ASSERT_TORQUE:
			if not is_equal_approx(_boat.airborne_rotation_torque, _expected_torque):
				_fail("PageUp 3x did not increase torque as expected (expected %f, got %f)" % [_expected_torque, _boat.airborne_rotation_torque])
			_press_key(KEY_D)
			_start_phase(Phase.HOLD_D_HIGH_TORQUE, 1)
			return

		Phase.HOLD_D_HIGH_TORQUE:
			_max_angular_velocity_boosted = maxf(_max_angular_velocity_boosted, _boat.angular_velocity)
			if _phase_timer < hold_d_high_torque_seconds:
				return
			_release_key(KEY_D)
			_start_phase(Phase.ASSERT_TORQUE_VELOCITY, 1)
			return

		Phase.ASSERT_TORQUE_VELOCITY:
			if not (_max_angular_velocity_boosted > _max_angular_velocity_initial):
				_fail("Higher torque did not produce higher angular velocity (initial max %f, boosted max %f)" % [_max_angular_velocity_initial, _max_angular_velocity_boosted])
			_start_phase(Phase.DONE)
			_finish()
			return

		Phase.DONE:
			pass


func _find_boat() -> Boat:
	var container := _debug.get_node_or_null("BoatContainer")
	if container == null:
		return null
	for child in container.get_children():
		if child is Boat:
			return child as Boat
	return null


func _assert_reset() -> void:
	if _boat.global_position.distance_to(_initial_position) > position_tolerance:
		_fail("Reset did not restore position (expected %v, got %v)" % [_initial_position, _boat.global_position])
	if absf(wrapf(_boat.global_rotation - _initial_rotation, -PI, PI)) > rotation_tolerance:
		_fail("Reset did not restore rotation within tolerance (expected %f, got %f)" % [_initial_rotation, _boat.global_rotation])
	if _boat.linear_velocity.length() > position_tolerance:
		_fail("Reset did not zero linear velocity (%v)" % _boat.linear_velocity)
	if absf(_boat.angular_velocity) > angular_velocity_tolerance:
		_fail("Reset did not zero angular velocity within tolerance (got %f)" % _boat.angular_velocity)


func _start_phase(next_phase: Phase, frames_to_settle: int = 0) -> void:
	_phase = next_phase
	_phase_timer = 0.0
	_settle_frames = frames_to_settle


func _press_key(keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	ev.echo = false
	Input.parse_input_event(ev)


func _release_key(keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = false
	ev.echo = false
	Input.parse_input_event(ev)


func _fail(message: String) -> void:
	_failures.append(message)
	_exit_code = 1


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: BoatRotationDebug interactive controls verified.")
	else:
		print("FAIL: BoatRotationDebug interactive controls verification failed:")
		for message in _failures:
			print("  - %s" % message)
	get_tree().quit(_exit_code)
