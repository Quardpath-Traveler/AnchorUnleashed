extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")

@export var time_scale_tolerance: float = 0.001
@export var fail_on_regression: bool = false

var _failures: Array[String] = []


func _ready() -> void:
	Engine.time_scale = 1.0

	_run_space_slowdown_case()
	_run_space_recovery_case()
	_run_anchor_launch_does_not_change_time_scale_case()

	var failed := not _failures.is_empty()
	print("ANCHOR_BULLET_TIME_RESULT %s" % JSON.stringify({
		"failures": _failures,
		"failed": failed,
	}))

	Engine.time_scale = 1.0
	if fail_on_regression and failed:
		get_tree().quit(1)
	else:
		get_tree().quit()


func _run_space_slowdown_case() -> void:
	var boat := _spawn_boat(Vector2.ZERO)

	if not _has_bullet_time_action():
		_cleanup_nodes([boat])
		return

	Input.action_press("bullet_time")
	_step_real_time(boat, _get_boat_float(boat, "bullet_time_slowdown_seconds", 0.18) * 0.5)
	_expect_time_scale(
		"space: halfway through slowdown blends toward bullet time",
		_get_expected_time_scale(1.0, _get_boat_float(boat, "aim_time_scale", 0.25), 0.5)
	)

	_step_real_time(boat, _get_boat_float(boat, "bullet_time_slowdown_seconds", 0.18) * 0.5)
	_expect_time_scale("space: held reaches bullet time", boat.get("aim_time_scale"))

	Input.action_release("bullet_time")
	_cleanup_nodes([boat])


func _run_space_recovery_case() -> void:
	var boat := _spawn_boat(Vector2(0.0, 220.0))

	if not _has_bullet_time_action():
		_cleanup_nodes([boat])
		return

	Input.action_press("bullet_time")
	_step_real_time(boat, _get_boat_float(boat, "bullet_time_slowdown_seconds", 0.18))
	_expect_time_scale("space: starts recovery from bullet time", boat.get("aim_time_scale"))

	Input.action_release("bullet_time")
	_step_real_time(boat, _get_boat_float(boat, "bullet_time_recover_seconds", 0.25) * 0.5)
	_expect_time_scale(
		"space: halfway through release blends toward normal time",
		_get_expected_time_scale(_get_boat_float(boat, "aim_time_scale", 0.25), 1.0, 0.5)
	)

	_step_real_time(boat, _get_boat_float(boat, "bullet_time_recover_seconds", 0.25) * 0.5)
	_expect_time_scale("space: released reaches normal time", 1.0)

	_cleanup_nodes([boat])


func _run_anchor_launch_does_not_change_time_scale_case() -> void:
	var boat := _spawn_boat(Vector2(0.0, 440.0))
	var anchor: Variant = boat.get_node("AnchorSocket/Anchor")
	var origin: Vector2 = anchor.call("_get_rope_start_global")

	anchor.call("start_aim")
	_expect_time_scale("anchor: aim no longer changes time scale", 1.0)
	anchor.call("launch", origin + Vector2(520.0, 0.0))
	_expect_time_scale("anchor: launch no longer changes time scale", 1.0)

	_cleanup_nodes([boat])


func _spawn_boat(position: Vector2) -> Node2D:
	var boat := BOAT_SCENE.instantiate() as Node2D
	add_child(boat)
	boat.global_position = position
	boat.set("posture_logging_enabled", false)

	var anchor: Variant = boat.get_node("AnchorSocket/Anchor")
	anchor.set("launch_gravity_scale", 0.0)
	anchor.set("max_length", 1200.0)
	return boat


func _cleanup_nodes(nodes: Array) -> void:
	if InputMap.has_action("bullet_time"):
		Input.action_release("bullet_time")
	Engine.time_scale = 1.0
	for node in nodes:
		if node is Node:
			(node as Node).queue_free()


func _expect_time_scale(label: String, expected: float) -> void:
	if absf(Engine.time_scale - expected) > time_scale_tolerance:
		_failures.append("%s expected %.3f got %.3f" % [label, expected, Engine.time_scale])


func _get_expected_time_scale(from_scale: float, to_scale: float, progress: float) -> float:
	return lerpf(from_scale, to_scale, smoothstep(0.0, 1.0, progress))


func _step_real_time(boat: Node2D, seconds: float) -> void:
	boat.call("_physics_process", seconds * Engine.time_scale)


func _has_bullet_time_action() -> bool:
	if InputMap.has_action("bullet_time"):
		return true

	_failures.append("InputMap is missing bullet_time action")
	return false


func _get_boat_float(boat: Node2D, property_name: StringName, fallback: float) -> float:
	var value: Variant = boat.get(property_name)
	if value == null:
		return fallback

	return float(value)
