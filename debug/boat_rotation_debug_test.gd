extends Node2D

const DEBUG_SCENE := preload("res://debug/BoatRotationDebug.tscn")

enum Phase {
	WAIT_FOR_BOAT,
	HOLD_D,
	PRESS_PAGEUP,
	ASSERT_TORQUE,
	PRESS_RESET,
	ASSERT_RESET,
	PRESS_LOCK,
	ASSERT_LOCK,
	DONE,
}

@export var wait_seconds: float = 0.1
@export var hold_d_seconds: float = 1.0
@export var input_settle_seconds: float = 0.05
@export var reset_rotation_tolerance: float = 0.1
@export var reset_angular_velocity_tolerance: float = 1.0

var _debug: BoatRotationDebug
var _boat: Boat
var _phase: Phase = Phase.WAIT_FOR_BOAT
var _phase_timer: float = 0.0
var _initial_torque: float
var _max_angular_velocity: float = 0.0
var _failures: Array[String] = []
var _exit_code: int = 0


func _ready() -> void:
	_debug = DEBUG_SCENE.instantiate() as BoatRotationDebug
	add_child(_debug)


func _process(delta: float) -> void:
	_phase_timer += delta

	match _phase:
		Phase.WAIT_FOR_BOAT:
			if _phase_timer < wait_seconds:
				return
			_boat = _find_boat()
			if _boat == null or not is_instance_valid(_boat):
				_fail("Boat did not spawn")
				_finish()
				return
			_initial_torque = _boat.airborne_rotation_torque
			_start_phase(Phase.HOLD_D)
			_press_action("move_right")

		Phase.HOLD_D:
			_max_angular_velocity = maxf(_max_angular_velocity, _boat.angular_velocity)
			if _phase_timer < hold_d_seconds:
				return
			_release_action("move_right")
			if not (_max_angular_velocity > 0.0):
				_fail("Angular velocity did not become positive while holding D (max=%f)" % _max_angular_velocity)
			_start_phase(Phase.PRESS_PAGEUP)
			_press_action("ui_page_up")
			_release_action("ui_page_up")

		Phase.PRESS_PAGEUP:
			if _phase_timer < input_settle_seconds:
				return
			_start_phase(Phase.ASSERT_TORQUE)

		Phase.ASSERT_TORQUE:
			if not (_boat.airborne_rotation_torque > _initial_torque):
				_fail("PageUp did not increase airborne_rotation_torque (%f -> %f)" % [_initial_torque, _boat.airborne_rotation_torque])
			_start_phase(Phase.PRESS_RESET)
			_press_action("debug_reset")
			_release_action("debug_reset")

		Phase.PRESS_RESET:
			if _phase_timer < input_settle_seconds:
				return
			_start_phase(Phase.ASSERT_RESET)

		Phase.ASSERT_RESET:
			if not _boat.global_position.is_equal_approx(_debug._initial_position):
				_fail("Reset did not restore position (expected %v, got %v)" % [_debug._initial_position, _boat.global_position])
			if absf(_boat.global_rotation - _debug._initial_rotation) > reset_rotation_tolerance:
				_fail("Reset did not restore rotation within tolerance (expected %f, got %f)" % [_debug._initial_rotation, _boat.global_rotation])
			if not _boat.linear_velocity.is_zero_approx():
				_fail("Reset did not zero linear velocity (%v)" % _boat.linear_velocity)
			if absf(_boat.angular_velocity) > reset_angular_velocity_tolerance:
				_fail("Reset did not zero angular velocity within tolerance (expected ~0, got %f)" % _boat.angular_velocity)
			_start_phase(Phase.PRESS_LOCK)
			_press_key(KEY_L)
			_release_key(KEY_L)

		Phase.PRESS_LOCK:
			if _phase_timer < input_settle_seconds:
				return
			_start_phase(Phase.ASSERT_LOCK)

		Phase.ASSERT_LOCK:
			if _debug.position_locked:
				_fail("L did not toggle position_locked (still true)")
			_finish()


func _find_boat() -> Boat:
	var container := _debug.get_node_or_null("BoatContainer")
	if container == null:
		return null
	for child in container.get_children():
		if child is Boat:
			return child as Boat
	return null


func _start_phase(next_phase: Phase) -> void:
	_phase = next_phase
	_phase_timer = 0.0


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


func _press_action(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _release_action(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
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
