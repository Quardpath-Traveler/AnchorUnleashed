extends SceneTree

const WATER_SURFACE_SCENE := preload("res://scenes/level_parts/WaterSurface.tscn")
const EPSILON := 0.001


func _init() -> void:
	var water := WATER_SURFACE_SCENE.instantiate() as WaterSurface
	var boat := Node2D.new()
	var exit_code := 0
	var water_rotation := -0.5115192

	water.rotation = water_rotation
	water.set("current_flow_direction", -1)
	boat.global_rotation = water_rotation

	var expected_flow_direction := Vector2.RIGHT.rotated(water_rotation) * -1.0
	var actual_flow_direction := water.get_water_flow_direction()
	if not _is_vector_approx(actual_flow_direction, expected_flow_direction):
		push_error(
			"WaterSurface flow direction regression: reversed current produced %s, expected %s."
			% [actual_flow_direction, expected_flow_direction]
		)
		exit_code = 1

	var target_rotation := water.get_boat_target_rotation()
	if not is_equal_approx(target_rotation, water_rotation):
		push_error(
			"WaterSurface flow direction regression: target rotation is %s, expected %s."
			% [target_rotation, water_rotation]
		)
		exit_code = 1

	var landing_angle := water.get_landing_angle_degrees(boat)
	if not is_zero_approx(landing_angle):
		push_error(
			"WaterSurface flow direction regression: aligned boat landing angle is %s, expected 0."
			% landing_angle
		)
		exit_code = 1

	boat.free()
	water.free()
	if exit_code == 0:
		print("WaterSurface flow direction regression passed.")
	quit(exit_code)


func _is_vector_approx(actual: Vector2, expected: Vector2) -> bool:
	return (
		is_equal_approx(actual.x, expected.x)
		and is_equal_approx(actual.y, expected.y)
		and actual.distance_to(expected) <= EPSILON
	)
