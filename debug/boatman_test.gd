extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")

var _boat: Boat
var _boatman: Node2D
var _hand_pivot: Node2D
var _hand_sprite: Sprite2D
var _hand_point: Marker2D
var _anchor: Anchor
var _failures: Array[String] = []
var _finished: bool = false


func _ready() -> void:
	_boat = BOAT_SCENE.instantiate() as Boat
	_boat.posture_logging_enabled = false
	_boat.freeze = true
	add_child(_boat)
	call_deferred("_run_checks")


func _run_checks() -> void:
	# ── 1. Hierarchy ──
	_boatman = _boat.get_node_or_null("Boatman") as Node2D
	_assert(_boatman != null, "Boatman instance exists as child of Boat")

	_hand_pivot = _boatman.get_node_or_null("HandPivot") as Node2D
	_assert(_hand_pivot != null, "HandPivot exists")

	_hand_sprite = _boatman.get_node_or_null("HandPivot/HandSprite") as Sprite2D
	_assert(_hand_sprite != null, "HandSprite exists")

	_hand_point = _boatman.get_node_or_null("HandPivot/HandSprite/HandPoint") as Marker2D
	_assert(_hand_point != null, "HandPoint exists (user-added Marker2D)")

	# ── 2. Anchor resolves (the @onready ordering fix) ──
	_anchor = _boat.anchor
	_assert(_anchor != null, "Boat.anchor resolves via %%Anchor")

	var boatman_anchor: Variant = _boatman.get("anchor")
	_assert(boatman_anchor != null, "Boatman.anchor is not null (fixed @onready ordering)")
	_assert(boatman_anchor == _anchor, "Boatman.anchor == Boat.anchor (same instance)")

	# ── 3. Anchor is child of HandPivot ──
	var anchor_parent := _anchor.get_parent()
	_assert(anchor_parent == _hand_pivot, "Anchor is child of HandPivot")

	# ── 4. AnchorSocket retained as empty Marker2D ──
	var anchor_socket := _boat.get_node_or_null("AnchorSocket")
	_assert(anchor_socket != null, "AnchorSocket retained as empty Marker2D")
	if anchor_socket != null:
		_assert(anchor_socket.get_child_count() == 0, "AnchorSocket has no children")

	# ── 5. Default rotation is 0 ──
	_assert(is_zero_approx(_hand_pivot.rotation), "HandPivot default rotation is 0")

	# ── 6. Base arm angle calibrated from HandPoint ──
	var base_arm_angle: float = _boatman.get("_base_arm_angle")
	var expected_hand_point_local := _hand_pivot.to_local(_hand_point.global_position)
	var expected_base_angle := expected_hand_point_local.angle()
	_assert(is_equal_approx(base_arm_angle, expected_base_angle),
		"Base arm angle = atan2(HandPoint local), got %.4f expected %.4f" % [base_arm_angle, expected_base_angle])

	# ── 7. socket_offset = HandPoint position relative to HandPivot ──
	_assert(_anchor.socket_offset.is_equal_approx(expected_hand_point_local),
		"socket_offset = HandPoint local position, got %s expected %s" % [_anchor.socket_offset, expected_hand_point_local])

	# ── 8. socket_rotation = base_arm_angle (逆时针90° from previous +PI/2) ──
	var expected_socket_rotation := base_arm_angle
	_assert(is_equal_approx(_anchor.socket_rotation, expected_socket_rotation),
		"socket_rotation = base_arm_angle (逆时针90°), got %.4f expected %.4f" % [_anchor.socket_rotation, expected_socket_rotation])

	# ── 9. Anchor at socket position after calibration ──
	_assert(_anchor.position.is_equal_approx(_anchor.socket_offset),
		"Anchor position = socket_offset after calibration, got %s" % _anchor.position)
	_assert(is_equal_approx(_anchor.rotation, _anchor.socket_rotation),
		"Anchor rotation = socket_rotation after calibration, got %.4f" % _anchor.rotation)

	# ── 10. Signal connection: start_aim sets _aiming = true ──
	_anchor.start_aim()
	await get_tree().process_frame
	var aiming: bool = _boatman.get("_aiming")
	_assert(aiming, "Boatman._aiming is true after anchor.start_aim() (signal connected)")
	_assert(_anchor.state == Anchor.State.AIMING, "Anchor state is AIMING after start_aim()")

	# ── 11. Hand auto-rotates when aiming (360° spin, clockwise) ──
	var rotation_before: float = _hand_pivot.rotation
	var spin_angle_before: float = _boatman.get("_aim_spin_angle")

	for i in 30:
		await get_tree().process_frame

	var spin_angle_after: float = _boatman.get("_aim_spin_angle")
	var rotation_after: float = _hand_pivot.rotation

	# _aim_spin_angle should have increased (clockwise = positive direction)
	_assert(spin_angle_after > spin_angle_before,
		"_aim_spin_angle increased (clockwise spin), before=%.4f after=%.4f" % [spin_angle_before, spin_angle_after])

	# Hand rotation should also be moving clockwise (increasing, modulo wrap)
	var actual_delta := angle_difference(rotation_before, rotation_after)
	_assert(actual_delta > 0.0,
		"HandPivot rotation moved clockwise, before=%.4f after=%.4f delta=%.4f" % [rotation_before, rotation_after, actual_delta])

	# ── 12. Hand continues spinning (not mouse-follow) ──
	var rotation_mid: float = _hand_pivot.rotation
	for i in 30:
		await get_tree().process_frame
	var rotation_later: float = _hand_pivot.rotation
	var continued_delta := angle_difference(rotation_mid, rotation_later)
	_assert(continued_delta > 0.0,
		"HandPivot continues clockwise spin, mid=%.4f later=%.4f delta=%.4f" % [rotation_mid, rotation_later, continued_delta])

	# ── 13. Launch stops aiming and enters FLYING ──
	var target := _hand_pivot.global_position + Vector2(80, 40)
	_anchor.launch(target)
	await get_tree().process_frame
	aiming = _boatman.get("_aiming")
	_assert(not aiming, "Boatman._aiming is false after launch (launched signal)")
	_assert(_anchor.state == Anchor.State.FLYING, "Anchor state is FLYING after launch()")
	_assert(_anchor.top_level, "Anchor top_level=true during FLYING")

	# ── 14. Recall returns to READY and restores socket ──
	_anchor.recall()
	await get_tree().physics_frame
	_assert(_anchor.state == Anchor.State.READY, "Anchor state is READY after recall()")
	_assert(not _anchor.top_level, "Anchor top_level=false after recall")
	_assert(_anchor.position.is_equal_approx(_anchor.socket_offset),
		"Anchor position restored to socket_offset after recall")
	_assert(is_equal_approx(_anchor.rotation, _anchor.socket_rotation),
		"Anchor rotation restored to socket_rotation after recall")

	# ── 15. Carrier velocity walk-up still finds Boat ──
	_assert(_boat is RigidBody2D, "Boat is RigidBody2D (carrier velocity source)")

	# ── 16. Rope start = HandPoint global position ──
	var rope_start := _anchor._get_rope_start_global()
	var hand_point_global := _hand_point.global_position
	_assert(is_equal_approx(rope_start.x, hand_point_global.x) and is_equal_approx(rope_start.y, hand_point_global.y),
		"Rope start global = HandPoint global position, got %s expected %s" % [rope_start, hand_point_global])

	# ── 17. HOOKED state: hand returns to default position ──
	# Simulate hook by creating a fake hook point.
	var fake_hook := Marker2D.new()
	fake_hook.global_position = _hand_pivot.global_position + Vector2(-60, 80)
	add_child(fake_hook)
	# Force anchor into HOOKED state.
	_anchor.state = Anchor.State.HOOKED
	_anchor.attached_hook_point = fake_hook
	_anchor.hooked.emit(fake_hook)
	await get_tree().process_frame
	await get_tree().process_frame  # Let _on_anchor_hooked run
	var hooked_aiming: bool = _boatman.get("_aiming")
	_assert(not hooked_aiming, "Boatman._aiming is false when hooked")

	# Process frames for hand to return to default.
	for i in 120:
		await get_tree().process_frame

	var hook_actual: float = _hand_pivot.rotation
	_assert(abs(angle_difference(hook_actual, 0.0)) < 0.05,
		"HandPivot rotation returns to default (0) when hooked, got %.4f" % hook_actual)

	# Cleanup.
	_anchor.recall()
	fake_hook.queue_free()

	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		print("FAIL: %s" % message)
		_failures.append(message)


func _finish() -> void:
	if _finished:
		return
	_finished = true

	if _failures.is_empty():
		print("PASS: Boatman hand rotation + anchor binding regression passed.")
		get_tree().quit(0)
	else:
		print("FAIL: Boatman regression failed:")
		for failure in _failures:
			print("  - %s" % failure)
		get_tree().quit(1)
