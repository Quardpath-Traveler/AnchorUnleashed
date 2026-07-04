class_name Boat
extends RigidBody2D

const CREW_MEMBER_SCENE := preload("res://scenes/characters/BoatCrewNPC.tscn")
const TRICK_FULL_ROTATION_RADIANS: float = TAU
const TRICK_360_NAME: String = "360"

signal crew_count_changed(count: int)
signal crew_lost(count: int)
signal crew_gained(count: int)

@export var airborne_rotation_torque: float = 78000.0
@export var counter_rotation_boost: float = 2.0
@export var counter_rotation_zero_threshold: float = 0.05
@export var airborne_nose_down_torque: float = 15000.0
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
@export var max_linear_speed: float = 0.0
@export var bad_landing_righting_torque: float = 80000.0
@export var bad_landing_righting_duration: float = 0.5
@export var bad_landing_righting_damping: float = 3200.0
@export var bad_landing_min_trigger_interval: float = 0.3
@export var respawn_recovery_grace: float = 0.5
@export var max_crew_count: int = 5
@export var crew_visual_origin: Vector2 = Vector2(0.0, 13.0)
@export var crew_visual_spacing: float = 12.5
@export var crew_visual_scale: Vector2 = Vector2(0.42, 0.42)
@export var crew_count: int = 3:
	set(value):
		crew_count = clampi(value, 0, max_crew_count)
		crew_count_changed.emit(crew_count)
		if is_inside_tree():
			_sync_crew_visuals()

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
var _airborne_rotation_total: float = 0.0
var _last_trick_rotation: float = 0.0
var _pending_360_tricks: int = 0
var _was_tracking_airborne_trick: bool = false

enum RespawnState { NONE, RECALL, LAUNCH, RECOVER }

var _respawn_state: RespawnState = RespawnState.NONE
var _respawn_target: Vector2 = Vector2.ZERO
var _respawn_recovery_timer: float = 0.0
var _righting_timer: float = 0.0
var _righting_target_rotation: float = 0.0
var _last_bad_landing_water: Node2D = null
var _last_bad_landing_time: float = -1000.0

@onready var anchor: Variant = %Anchor
@onready var crew_visuals: Node2D = %CrewVisuals


func _ready() -> void:
	add_to_group("boats")
	_sync_crew_visuals()
	EventBus.player_spawned.emit(self)
	crew_count_changed.emit(crew_count)
	anchor.aim_started.connect(_on_anchor_aim_started)
	anchor.launched.connect(_on_anchor_launched)
	anchor.hooked.connect(_on_anchor_hooked)
	anchor.recalled.connect(_on_anchor_recalled)


func _physics_process(delta: float) -> void:
	_update_manual_bullet_time(delta)
	_update_respawn_recovery_timer(delta)
	_update_respawn_state(delta)
	_update_airborne_trick_tracking()

	if _respawn_state != RespawnState.NONE:
		_update_posture_log(delta)
		return

	_update_anchor_aim_target()

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
	if _respawn_state != RespawnState.NONE:
		return

	if event.is_action_pressed("confirm"):
		if anchor.is_active():
			anchor.recall()
		else:
			anchor.start_aim()
	elif event.is_action_released("confirm") and anchor.is_aiming:
		anchor.launch(get_global_mouse_position())


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	_contact_count = state.get_contact_count()

	if _respawn_state == RespawnState.LAUNCH:
		_execute_respawn_launch(state)
		_respawn_state = RespawnState.RECOVER

	if _respawn_state != RespawnState.NONE:
		state.angular_velocity = clampf(
			state.angular_velocity,
			-max_angular_velocity,
			max_angular_velocity
		)
		_limit_linear_speed(state)
		return

	_apply_anchor_constraint(state)
	_apply_bad_landing_righting(state)
	state.angular_velocity = clampf(
		state.angular_velocity,
		-max_angular_velocity,
		max_angular_velocity
	)
	_limit_linear_speed(state)


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
	crew_count -= amount

	if crew_count < previous_count:
		crew_lost.emit(crew_count)
		GameState.set_rescued_count(crew_count)


func gain_crew(amount: int = 1) -> void:
	var previous_count := crew_count
	crew_count += amount

	if crew_count > previous_count:
		crew_gained.emit(crew_count)


func _sync_crew_visuals() -> void:
	if crew_visuals == null:
		return

	for child in crew_visuals.get_children():
		crew_visuals.remove_child(child)
		child.queue_free()

	if crew_count <= 0:
		return

	var row_width := crew_visual_spacing * float(crew_count - 1)
	for index in range(crew_count):
		var crew_member := CREW_MEMBER_SCENE.instantiate() as Node2D
		crew_member.name = "CrewMember%d" % (index + 1)
		crew_member.position = crew_visual_origin + Vector2(
			float(index) * crew_visual_spacing - row_width * 0.5,
			0.0
		)
		crew_member.scale = crew_visual_scale
		crew_visuals.add_child(crew_member)


func _update_anchor_aim_target() -> void:
	if anchor.is_aiming:
		anchor.update_aim_target(get_global_mouse_position())


func _update_airborne_trick_tracking() -> void:
	if is_airborne():
		if not _was_tracking_airborne_trick:
			_was_tracking_airborne_trick = true
			_last_trick_rotation = global_rotation
			return

		var rotation_delta := absf(wrapf(global_rotation - _last_trick_rotation, -PI, PI))
		_last_trick_rotation = global_rotation
		_airborne_rotation_total += rotation_delta

		while _airborne_rotation_total >= TRICK_FULL_ROTATION_RADIANS:
			_pending_360_tricks += 1
			_airborne_rotation_total -= TRICK_FULL_ROTATION_RADIANS
	else:
		if not is_in_water():
			_reset_trick_tracking()


func _reset_trick_tracking() -> void:
	_airborne_rotation_total = 0.0
	_last_trick_rotation = global_rotation
	_pending_360_tricks = 0
	_was_tracking_airborne_trick = false


func is_respawning() -> bool:
	return _respawn_state != RespawnState.NONE


func respawn_at(target_position: Vector2) -> void:
	if _respawn_state != RespawnState.NONE:
		return
	if _respawn_recovery_timer > 0.0:
		return
	_reset_trick_tracking()
	_respawn_state = RespawnState.RECALL
	_respawn_target = target_position


func on_bad_landing(angle_degrees: float, target_rotation: float, water_surface: Node2D) -> void:
	_reset_trick_tracking()

	if water_surface == _last_bad_landing_water:
		if Time.get_ticks_msec() / 1000.0 - _last_bad_landing_time < bad_landing_min_trigger_interval:
			return

	lose_crew(1)
	_righting_timer = bad_landing_righting_duration
	_righting_target_rotation = target_rotation
	_last_bad_landing_water = water_surface
	_last_bad_landing_time = Time.get_ticks_msec() / 1000.0


func on_safe_landing(landing_angle_degrees: float, water_surface: Node2D) -> void:
	for _index in range(_pending_360_tricks):
		GameState.award_trick(TRICK_360_NAME, GameState.TRICK_360_SCORE_VALUE)
	_reset_trick_tracking()


func _limit_linear_speed(state: PhysicsDirectBodyState2D) -> void:
	if max_linear_speed <= 0.0:
		return

	if state.linear_velocity.length() > max_linear_speed:
		state.linear_velocity = state.linear_velocity.normalized() * max_linear_speed


func _apply_bad_landing_righting(state: PhysicsDirectBodyState2D) -> void:
	if _righting_timer <= 0.0:
		return

	_righting_timer -= state.step
	var decay := clampf(_righting_timer / bad_landing_righting_duration, 0.0, 1.0)

	var rotation_error := wrapf(state.transform.get_rotation() - _righting_target_rotation, -PI, PI)
	var righting_torque := (
		-rotation_error * bad_landing_righting_torque * decay
		- state.angular_velocity * bad_landing_righting_damping * decay
	)
	state.apply_torque(righting_torque)


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


func _update_respawn_recovery_timer(delta: float) -> void:
	if _respawn_recovery_timer > 0.0:
		_respawn_recovery_timer = maxf(_respawn_recovery_timer - delta, 0.0)


func _update_respawn_state(_delta: float) -> void:
	match _respawn_state:
		RespawnState.RECALL:
			_recall_anchor_for_respawn()
			_respawn_state = RespawnState.LAUNCH
		RespawnState.RECOVER:
			if is_in_water() or _contact_count > 0:
				_respawn_recovery_timer = respawn_recovery_grace
				_respawn_state = RespawnState.NONE


func _recall_anchor_for_respawn() -> void:
	if anchor.is_active() or anchor.is_hooked():
		anchor.recall()
	_reset_anchor_swing_state()


func _execute_respawn_launch(state: PhysicsDirectBodyState2D) -> void:
	state.transform.origin = _respawn_target
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0.0
	_reset_trick_tracking()
	if crew_count > 0:
		lose_crew(1)


func _vector_to_log_data(value: Vector2) -> Dictionary:
	return {
		"x": snappedf(value.x, 0.001),
		"y": snappedf(value.y, 0.001),
	}


func _on_anchor_aim_started() -> void:
	_update_anchor_aim_target()


func _on_anchor_launched(_target_position: Vector2) -> void:
	_reset_anchor_swing_state()


func _on_anchor_hooked(_hook_point: Node2D) -> void:
	_reset_anchor_swing_state()


func _on_anchor_recalled() -> void:
	_reset_anchor_swing_state()
