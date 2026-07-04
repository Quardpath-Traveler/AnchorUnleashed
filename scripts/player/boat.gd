class_name Boat
extends RigidBody2D

signal crew_count_changed(count: int)
signal crew_lost(count: int)

@export var airborne_rotation_torque: float = 90000.0
@export var counter_rotation_boost: float = 2.0
@export var counter_rotation_zero_threshold: float = 0.05
@export var airborne_nose_down_torque: float = 18000.0
@export var airborne_nose_down_damping: float = 1200.0
@export var posture_logging_enabled: bool = true
@export_range(0.05, 5.0, 0.05) var posture_log_interval_seconds: float = 0.25
@export var posture_log_prefix: String = "BOAT_POSTURE"
@export_range(0.05, 1.0) var aim_time_scale: float = 0.25
@export_range(0.01, 2.0, 0.01) var bullet_time_slowdown_seconds: float = 0.18
@export_range(0.01, 2.0, 0.01) var bullet_time_recover_seconds: float = 0.25
@export_range(0.0, 1.0) var rope_pull_stiffness: float = 1.0
@export var swing_turnaround_speed: float = 40.0
@export var anchor_swing_alignment_torque: float = 48.0
@export var anchor_swing_alignment_damping: float = 0.2
@export var anchor_swing_alignment_max_angular_velocity: float = 9.0
@export var max_angular_velocity: float = 9.0
@export var anchor_swing_target_turn_speed: float = 10.0
@export var crew_count: int = 3:
	set(value):
		crew_count = max(value, 0)
		crew_count_changed.emit(crew_count)

var _contact_count: int = 0
var _water_contact_count: int = 0
var _posture_log_elapsed: float = 0.0
var _swing_locked_energy: float = -1.0
var _swing_tangent_sign: float = 1.0
var _anchor_swing_target_rotation: float = 0.0
var _has_anchor_swing_target_rotation: bool = false
var _manual_bullet_time_target_scale: float = 1.0
var _manual_bullet_time_start_scale: float = 1.0
var _manual_bullet_time_transition_elapsed: float = 0.0
var _is_counter_rotation_boost_active: bool = false

@onready var anchor: Variant = %Anchor


func _ready() -> void:
	add_to_group("boats")
	EventBus.player_spawned.emit(self)
	crew_count_changed.emit(crew_count)
	anchor.aim_started.connect(_on_anchor_aim_started)
	anchor.launched.connect(_on_anchor_launched)
	anchor.hooked.connect(_on_anchor_hooked)
	anchor.recalled.connect(_on_anchor_recalled)


func _physics_process(delta: float) -> void:
	_update_manual_bullet_time(delta)

	var rotation_input := Input.get_axis("move_left", "move_right")
	if is_airborne():
		if not anchor.is_hooked():
			_apply_airborne_nose_down()
		if not is_zero_approx(rotation_input):
			_update_counter_rotation_boost(rotation_input)
			var torque := airborne_rotation_torque
			if _is_counter_rotation_boost_active:
				torque *= counter_rotation_boost
			apply_torque(rotation_input * torque)

	_update_posture_log(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm"):
		if anchor.is_active():
			anchor.recall()
		else:
			anchor.start_aim()
	elif event.is_action_released("confirm") and anchor.is_aiming:
		anchor.launch(get_global_mouse_position())


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_contact_count = state.get_contact_count()
	_apply_anchor_constraint(state)
	state.angular_velocity = clampf(
		state.angular_velocity,
		-max_angular_velocity,
		max_angular_velocity
	)


func is_airborne() -> bool:
	return _contact_count == 0 and not is_in_water()


func is_in_water() -> bool:
	return _water_contact_count > 0


func enter_water() -> void:
	_water_contact_count += 1


func exit_water() -> void:
	_water_contact_count = maxi(_water_contact_count - 1, 0)


func get_posture_log_data() -> Dictionary:
	var anchor_swing_target_degrees: Variant = null
	var anchor_swing_alignment_error_degrees: Variant = null
	if _has_anchor_swing_target_rotation:
		anchor_swing_target_degrees = snappedf(rad_to_deg(_anchor_swing_target_rotation), 0.001)
		anchor_swing_alignment_error_degrees = snappedf(
			_get_anchor_swing_alignment_error_degrees(),
			0.001
		)

	return {
		"time_msec": Time.get_ticks_msec(),
		"position": _vector_to_log_data(global_position),
		"rotation_degrees": snappedf(rad_to_deg(global_rotation), 0.001),
		"nose_angle_degrees": snappedf(rad_to_deg(global_transform.x.angle()), 0.001),
		"anchor_swing_target_degrees": anchor_swing_target_degrees,
		"anchor_swing_alignment_error_degrees": anchor_swing_alignment_error_degrees,
		"angular_velocity": snappedf(angular_velocity, 0.001),
		"linear_velocity": _vector_to_log_data(linear_velocity),
		"speed": snappedf(linear_velocity.length(), 0.001),
		"mass": snappedf(mass, 0.001),
		"contact_count": _contact_count,
		"water_contact_count": _water_contact_count,
		"in_water": is_in_water(),
		"airborne": is_airborne(),
		"sleeping": sleeping,
	}


func emit_posture_log() -> void:
	print("%s %s" % [posture_log_prefix, JSON.stringify(get_posture_log_data())])


func lose_crew(amount: int = 1) -> void:
	var previous_count := crew_count
	crew_count = max(crew_count - amount, 0)

	if crew_count < previous_count:
		crew_lost.emit(crew_count)


func _apply_anchor_constraint(state: PhysicsDirectBodyState2D) -> void:
	if not anchor.is_hooked():
		_reset_anchor_swing_state()
		return

	var hook_position: Vector2 = anchor.get_hook_global_position()
	var rope_limit: float = anchor.get_rope_length()
	if rope_limit <= 0.0:
		return

	var from_hook: Vector2 = state.transform.origin - hook_position
	var distance: float = from_hook.length()
	if is_zero_approx(distance):
		from_hook = Vector2.DOWN * rope_limit
		distance = rope_limit

	var rope_direction: Vector2 = from_hook / distance
	var corrected_transform := state.transform
	corrected_transform.origin = hook_position + rope_direction * rope_limit
	state.transform = corrected_transform

	var tangent_direction := _get_tangent_direction(rope_direction)
	if _swing_locked_energy < 0.0:
		_capture_anchor_swing_state(state, rope_direction, tangent_direction, rope_limit)

	var current_tangent_speed := state.linear_velocity.dot(tangent_direction)
	if not is_zero_approx(current_tangent_speed):
		_swing_tangent_sign = signf(current_tangent_speed)

	var potential_energy := _get_anchor_swing_potential_energy(rope_direction, rope_limit)
	var target_tangent_speed := sqrt(2.0 * maxf(_swing_locked_energy - potential_energy, 0.0))
	if target_tangent_speed <= swing_turnaround_speed:
		_update_swing_direction_from_gravity(tangent_direction)
	state.linear_velocity = tangent_direction * target_tangent_speed * _swing_tangent_sign
	_update_anchor_swing_target_rotation(state.linear_velocity.angle(), state)
	_align_bow_to_anchor_swing(state)


func _capture_anchor_swing_state(
	state: PhysicsDirectBodyState2D,
	rope_direction: Vector2,
	tangent_direction: Vector2,
	rope_limit: float
) -> void:
	var tangent_speed := state.linear_velocity.dot(tangent_direction)
	if not is_zero_approx(tangent_speed):
		_swing_tangent_sign = signf(tangent_speed)

	_swing_locked_energy = (
		_get_anchor_swing_potential_energy(rope_direction, rope_limit)
		+ 0.5 * tangent_speed * tangent_speed
	)


func _reset_anchor_swing_state() -> void:
	_swing_locked_energy = -1.0
	_swing_tangent_sign = 1.0
	_has_anchor_swing_target_rotation = false


func _update_manual_bullet_time(delta: float) -> void:
	var next_target_scale := _get_manual_bullet_time_target_scale()
	if not is_equal_approx(next_target_scale, _manual_bullet_time_target_scale):
		_manual_bullet_time_target_scale = next_target_scale
		_manual_bullet_time_start_scale = Engine.time_scale
		_manual_bullet_time_transition_elapsed = 0.0

	var transition_seconds := bullet_time_slowdown_seconds
	if is_equal_approx(_manual_bullet_time_target_scale, 1.0):
		transition_seconds = bullet_time_recover_seconds

	_manual_bullet_time_transition_elapsed += _get_unscaled_delta(delta)
	var transition_progress := clampf(
		_manual_bullet_time_transition_elapsed / maxf(transition_seconds, 0.001),
		0.0,
		1.0
	)
	Engine.time_scale = lerpf(
		_manual_bullet_time_start_scale,
		_manual_bullet_time_target_scale,
		smoothstep(0.0, 1.0, transition_progress)
	)


func _get_manual_bullet_time_target_scale() -> float:
	if Input.is_action_pressed("bullet_time"):
		return aim_time_scale

	return 1.0


func _get_unscaled_delta(delta: float) -> float:
	return delta / maxf(Engine.time_scale, 0.001)


func _get_tangent_direction(rope_direction: Vector2) -> Vector2:
	return Vector2(-rope_direction.y, rope_direction.x).normalized()


func _get_anchor_swing_potential_energy(rope_direction: Vector2, rope_limit: float) -> float:
	var gravity_direction := _get_gravity_direction()
	if gravity_direction.is_zero_approx():
		return 0.0

	return _get_gravity_acceleration() * rope_limit * (1.0 - rope_direction.dot(gravity_direction))


func _update_swing_direction_from_gravity(tangent_direction: Vector2) -> void:
	var gravity_tangent := _get_gravity_direction().dot(tangent_direction)
	if not is_zero_approx(gravity_tangent):
		_swing_tangent_sign = signf(gravity_tangent)


func _update_anchor_swing_target_rotation(
	desired_rotation: float,
	state: PhysicsDirectBodyState2D
) -> void:
	if not _has_anchor_swing_target_rotation:
		_anchor_swing_target_rotation = state.transform.get_rotation()
		_has_anchor_swing_target_rotation = true
		return

	var rotation_step := anchor_swing_target_turn_speed * state.step
	var target_error := wrapf(desired_rotation - _anchor_swing_target_rotation, -PI, PI)
	_anchor_swing_target_rotation = wrapf(
		_anchor_swing_target_rotation + clampf(target_error, -rotation_step, rotation_step),
		-PI,
		PI
	)


func _align_bow_to_anchor_swing(state: PhysicsDirectBodyState2D) -> void:
	if state.linear_velocity.length() <= 1.0:
		return

	var current_rotation := state.transform.get_rotation()
	var rotation_error := wrapf(current_rotation - _anchor_swing_target_rotation, -PI, PI)
	var desired_angular_velocity := clampf(
		-rotation_error * anchor_swing_alignment_torque
		- state.angular_velocity * anchor_swing_alignment_damping,
		-anchor_swing_alignment_max_angular_velocity,
		anchor_swing_alignment_max_angular_velocity
	)
	state.angular_velocity = desired_angular_velocity


func _get_anchor_swing_alignment_error_degrees() -> float:
	if not _has_anchor_swing_target_rotation:
		return 0.0

	var nose_angle := global_transform.x.angle()
	return absf(rad_to_deg(wrapf(nose_angle - _anchor_swing_target_rotation, -PI, PI)))


func _get_gravity_direction() -> Vector2:
	var gravity_direction := ProjectSettings.get_setting("physics/2d/default_gravity_vector") as Vector2
	return gravity_direction.normalized()


func _get_gravity_acceleration() -> float:
	return float(ProjectSettings.get_setting("physics/2d/default_gravity")) * gravity_scale


func _apply_airborne_nose_down() -> void:
	var nose_down_rotation := Vector2.DOWN.angle()
	var rotation_error := wrapf(global_rotation - nose_down_rotation, -PI, PI)
	var nose_down_torque := (
		-rotation_error * airborne_nose_down_torque
		- angular_velocity * airborne_nose_down_damping
	)
	apply_torque(nose_down_torque)


func _update_counter_rotation_boost(input: float) -> void:
	if is_zero_approx(input):
		_is_counter_rotation_boost_active = false
		return

	if absf(angular_velocity) <= counter_rotation_zero_threshold:
		return

	var velocity_sign := signf(angular_velocity)
	var input_sign := signf(input)

	if _is_counter_rotation_boost_active:
		if velocity_sign == input_sign:
			_is_counter_rotation_boost_active = false
	else:
		if velocity_sign != input_sign:
			_is_counter_rotation_boost_active = true


func _update_posture_log(delta: float) -> void:
	if not posture_logging_enabled:
		return

	_posture_log_elapsed += delta
	if _posture_log_elapsed < posture_log_interval_seconds:
		return

	_posture_log_elapsed = 0.0
	emit_posture_log()


func _vector_to_log_data(value: Vector2) -> Dictionary:
	return {
		"x": snappedf(value.x, 0.001),
		"y": snappedf(value.y, 0.001),
	}


func _on_anchor_aim_started() -> void:
	pass


func _on_anchor_launched(_target_position: Vector2) -> void:
	_reset_anchor_swing_state()


func _on_anchor_hooked(_hook_point: Node2D) -> void:
	_reset_anchor_swing_state()


func _on_anchor_recalled() -> void:
	_reset_anchor_swing_state()
