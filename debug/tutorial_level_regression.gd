extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")
const TUTORIAL_LEVEL_SCENE := preload("res://scenes/levels/TutorialLevel.tscn")

@export var fail_on_regression: bool = false
@export var max_surface_gap: float = 34.0
@export var max_surface_depth: float = 74.0
@export var aim_position: Vector2 = Vector2(515.0, 205.0)
@export var first_release_position: Vector2 = Vector2(1120.0, 375.0)
@export var air_control_position: Vector2 = Vector2(1300.0, 430.0)
@export var final_aim_position: Vector2 = Vector2(1750.0, 480.0)
@export var final_release_position: Vector2 = Vector2(2247.0, 572.0)

var _level: TutorialLevel
var _boat: Boat
var _failed_checks: Array[String] = []
var _water_surfaces: Array[WaterSurface] = []


func _ready() -> void:
	_spawn_world()
	await get_tree().process_frame
	await get_tree().physics_frame
	_run_regression()


func _spawn_world() -> void:
	_level = TUTORIAL_LEVEL_SCENE.instantiate() as TutorialLevel
	add_child(_level)
	_collect_water_surfaces(_level)

	_boat = BOAT_SCENE.instantiate() as Boat
	add_child(_boat)
	_boat.posture_logging_enabled = false
	_boat.global_position = _level.get_start_position()
	_boat.linear_velocity = Vector2.ZERO
	_boat.angular_velocity = 0.0
	_level.setup(_boat)


func _run_regression() -> void:
	_check_water_surface_alignment()
	_check_prompt_sequence()
	_check_anchor_sequence()
	_print_result()


func _check_water_surface_alignment() -> void:
	for sample in [
		{"name": "start", "point": _level.get_start_position(), "water": "WaterSurface"},
		{"name": "aim", "point": aim_position, "water": "WaterSurface"},
		{"name": "first_release", "point": first_release_position, "water": "WaterSurface2"},
		{"name": "air_control", "point": air_control_position, "water": "WaterSurface2"},
		{"name": "final_aim", "point": final_aim_position, "water": "WaterSurface3"},
		{"name": "final_release", "point": final_release_position, "water": "WaterSurface3"},
	]:
		var water := _level.get_node_or_null(sample["water"]) as WaterSurface
		if water == null:
			_failed_checks.append("water_%s_missing" % sample["water"])
			continue

		var point := sample["point"] as Vector2
		var depth := water.get_surface_depth_at_global_position(point)
		var gap := maxf(-depth, 0.0)
		var too_high := gap > max_surface_gap
		var too_deep := depth > max_surface_depth
		var local_x := water.to_local(point).x
		var outside_visual_width := absf(local_x) > water.water_width * 0.5
		if too_high or too_deep:
			_failed_checks.append(
				"water_%s depth=%.3f gap=%.3f expected=%s"
				% [sample["name"], depth, gap, sample["water"]]
			)
		if outside_visual_width:
			_failed_checks.append(
				"water_%s outside_width local_x=%.3f half_width=%.3f expected=%s"
				% [sample["name"], local_x, water.water_width * 0.5, sample["water"]]
			)


func _check_prompt_sequence() -> void:
	var expected_image_paths := [
		"res://assets/art/UI/TutorialComponents/aim_at_rock_launch_anchor.png",
		"res://assets/art/UI/TutorialComponents/release_anchor.png",
		"res://assets/art/UI/TutorialComponents/timing_the_swing.png",
		"res://assets/art/UI/TutorialComponents/enter_bullet_time.png",
		"res://assets/art/UI/TutorialComponents/adjust_balance_collect_coins_dodge_obstacles.png",
		"res://assets/art/UI/TutorialComponents/rescue_more_before_flood.png",
	]
	for index in range(expected_image_paths.size()):
		var trigger := _level.tutorial_triggers.get_child(index) as TutorialTrigger
		if trigger == null:
			_failed_checks.append("prompt_trigger_%d_missing" % index)
			continue

		var prompt_sprite := trigger.get_node_or_null("PromptSprite") as Sprite2D
		if prompt_sprite == null:
			_failed_checks.append("prompt_sprite_%d_missing" % index)
			continue

		var texture := prompt_sprite.texture as Texture2D
		var actual := texture.resource_path if texture != null else "<null>"
		if actual != expected_image_paths[index]:
			_failed_checks.append(
				"prompt_%d expected=%s actual=%s"
				% [index, expected_image_paths[index], actual]
			)

		trigger.body_entered.emit(_boat)
		await get_tree().process_frame
		if not prompt_sprite.visible:
			_failed_checks.append("prompt_%d not visible after trigger" % index)


func _check_anchor_sequence() -> void:
	var first_hook := _level.get_node("HookPointThrowIntro") as Node2D
	var final_hook := _level.get_node("HookPointFinal") as Node2D

	_drive_anchor_step("first_hook", aim_position, first_hook)
	_boat.anchor.recall()
	if _boat.anchor.is_active():
		_failed_checks.append("first_recall_left_anchor_active")

	_drive_anchor_step("final_hook", final_aim_position, final_hook)
	_boat.anchor.recall()
	if _boat.anchor.is_active():
		_failed_checks.append("final_recall_left_anchor_active")


func _drive_anchor_step(step_name: String, boat_position: Vector2, hook: Node2D) -> void:
	_boat.global_position = boat_position
	_boat.linear_velocity = Vector2.ZERO
	_boat.angular_velocity = 0.0

	var socket_position: Vector2 = _boat.anchor.get_parent().global_position
	var hook_distance := socket_position.distance_to(hook.global_position)
	if hook_distance > _boat.anchor.max_length:
		_failed_checks.append(
			"%s_out_of_anchor_range distance=%.3f max=%.3f"
			% [step_name, hook_distance, _boat.anchor.max_length]
		)
		return

	_boat.anchor.start_aim()
	_boat.anchor.launch(hook.global_position)
	_boat.anchor.attach_to(hook)
	if not _boat.anchor.is_hooked():
		_failed_checks.append("%s_anchor_not_hooked" % step_name)


func _get_nearest_water_surface_data(point: Vector2) -> Dictionary:
	var nearest := {
		"name": "",
		"depth": -INF,
		"abs_depth": INF,
	}
	for water in _water_surfaces:
		var depth := water.get_surface_depth_at_global_position(point)
		var abs_depth := absf(depth)
		if abs_depth < nearest.abs_depth:
			nearest = {
				"name": water.name,
				"depth": depth,
				"abs_depth": abs_depth,
			}

	return nearest


func _collect_water_surfaces(node: Node) -> void:
	if node is WaterSurface:
		_water_surfaces.append(node as WaterSurface)

	for child in node.get_children():
		_collect_water_surfaces(child)


func _print_result() -> void:
	var failed := not _failed_checks.is_empty()
	print("TUTORIAL_LEVEL_RESULT %s" % JSON.stringify({
		"failed": failed,
		"failed_checks": _failed_checks,
		"water_samples": _get_water_sample_log(),
	}))

	if fail_on_regression and failed:
		get_tree().quit(1)
	else:
		get_tree().quit()


func _get_water_sample_log() -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	for sample in [
		{"name": "start", "point": _level.get_start_position(), "water": "WaterSurface"},
		{"name": "aim", "point": aim_position, "water": "WaterSurface"},
		{"name": "first_release", "point": first_release_position, "water": "WaterSurface2"},
		{"name": "air_control", "point": air_control_position, "water": "WaterSurface2"},
		{"name": "final_aim", "point": final_aim_position, "water": "WaterSurface3"},
		{"name": "final_release", "point": final_release_position, "water": "WaterSurface3"},
	]:
		var water := _level.get_node_or_null(sample["water"]) as WaterSurface
		var point := sample["point"] as Vector2
		var depth := NAN
		var local_x := NAN
		if water != null:
			depth = water.get_surface_depth_at_global_position(point)
			local_x = water.to_local(point).x
		var nearest := _get_nearest_water_surface_data(point)
		samples.append({
			"name": sample["name"],
			"point": _vector_to_log_data(point),
			"expected": sample["water"],
			"nearest": nearest["name"],
			"expected_depth": snappedf(depth, 0.001),
			"expected_local_x": snappedf(local_x, 0.001),
			"nearest_depth": snappedf(nearest["depth"], 0.001),
		})

	return samples


func _vector_to_log_data(value: Vector2) -> Dictionary:
	return {
		"x": snappedf(value.x, 0.001),
		"y": snappedf(value.y, 0.001),
	}
