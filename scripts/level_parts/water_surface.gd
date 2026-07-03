## Area that renders animated water, applies buoyancy/current forces to boats,
## and reports boat landing quality when a boat enters the water.
class_name WaterSurface
extends Area2D

## Emitted when a boat body first overlaps the water area.
signal boat_entered(boat: Node2D)
## Emitted when a boat body stops overlapping the water area.
signal boat_exited(boat: Node2D)
## Emitted when a boat enters the water within the safe landing angle.
signal boat_landed_safely(boat: Node2D, landing_angle_degrees: float)
## Emitted when a boat enters the water above the safe landing angle.
signal boat_bad_landing(boat: Node2D, landing_angle_degrees: float)

## Maximum absolute boat rotation, in degrees, that counts as a safe landing.
@export_range(0.0, 180.0, 1.0) var safe_landing_angle_degrees: float = 35.0
## Local horizontal span of the water body.
@export var water_width: float = 1400.0
## Local vertical depth of the water body below the animated surface.
@export var water_depth: float = 180.0
## Baseline local Y coordinate used as the center line for surface waves.
@export var surface_y: float = -70.0
## Height of the primary animated surface wave.
@export var wave_amplitude: float = 14.0
## Horizontal frequency of the primary surface wave.
@export var wave_frequency: float = 0.028
## Height of the secondary animated surface wave.
@export var secondary_wave_amplitude: float = 6.0
## Horizontal frequency of the secondary surface wave.
@export var secondary_wave_frequency: float = 0.057
## Visual flow speed and entry impulse strength along the water direction.
@export var current_flow_speed: float = 90.0
## Continuous force applied to floating boats along the water direction.
@export var current_force: float = 260.0
## Base upward force applied to submerged boats.
@export var buoyancy_force: float = 1600.0
## Upper clamp for total upward buoyancy force, including damping.
@export var max_buoyancy_force: float = 2600.0
## Submerged depth where buoyancy reaches full strength.
@export var target_float_depth: float = 24.0
## Damping multiplier used to reduce downward velocity while floating.
@export var buoyancy_damping: float = 10.0
## One-time upward impulse applied when a rigid boat enters the water.
@export var fountain_impulse: float = 360.0
## Crew loss applied when a boat lands above the safe angle.
@export var unsafe_landing_crew_loss: int = 1
## Enables the edge waterfall visual and downward edge force.
@export var enable_waterfall: bool = true
## Waterfall edge side in local space: positive for right, negative for left.
@export var waterfall_side: int = 1
## Local width of the waterfall curtain beyond the water edge.
@export var waterfall_width: float = 80.0
## Local drop height of the waterfall curtain.
@export var waterfall_height: float = 180.0
## Downward force applied to boats near the waterfall edge.
@export var waterfall_down_force: float = 900.0
## Local length of the curved water lip before the waterfall curtain.
@export var waterfall_lip_length: float = 42.0
## Fill color for the main water body.
@export var water_color: Color = Color(0.05, 0.34, 0.64, 0.78)
## Fill color for the lower, deeper part of the water body.
@export var deep_water_color: Color = Color(0.03, 0.18, 0.38, 0.92)
## Stroke color for foam, surface highlights, and waterfall splash arcs.
@export var foam_color: Color = Color(0.82, 0.95, 1.0, 0.88)
## Boat mass that the exported water force values were tuned against.
@export var reference_boat_mass: float = 2.336
## Torque used to rotate submerged boats back toward the water flow direction.
@export var angular_stability_torque: float = 3000.0
## Torque used to slow submerged boat angular velocity.
@export var angular_damping_torque: float = 2600.0
## Rotation error multiplier used to choose a stable water angular velocity.
@export var angular_recovery_speed: float = 8.0
## Maximum angular velocity allowed while a boat is stabilized by water.
@export var max_water_angular_velocity: float = 1.1
## How strongly water blends the boat angular velocity toward the stable target.
@export_range(0.0, 1.0, 0.05) var angular_stability_blend: float = 0.85
## Minimum submerged ratio required before water starts stabilizing boat rotation.
@export_range(0.0, 1.0, 0.05) var water_stability_min_submerged_ratio: float = 0.35

var _time: float = 0.0
var _boats_in_water: Array[Node2D] = []

@onready var collision_shape: CollisionShape2D = %CollisionShape2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_sync_collision_shape()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _physics_process(_delta: float) -> void:
	_refresh_overlapping_boats()

	for boat in _boats_in_water:
		if not is_instance_valid(boat):
			continue

		_apply_buoyancy_to_boat(boat)


func _draw() -> void:
	var surface_points := _build_surface_points()
	var fill_points := surface_points.duplicate()
	fill_points.append(Vector2(water_width * 0.5, surface_y + water_depth))
	fill_points.append(Vector2(-water_width * 0.5, surface_y + water_depth))

	draw_colored_polygon(fill_points, water_color)
	draw_colored_polygon([
		Vector2(-water_width * 0.5, surface_y + water_depth * 0.45),
		Vector2(water_width * 0.5, surface_y + water_depth * 0.45),
		Vector2(water_width * 0.5, surface_y + water_depth),
		Vector2(-water_width * 0.5, surface_y + water_depth),
	], deep_water_color)
	draw_polyline(surface_points, foam_color, 3.0)
	_draw_flow_lines()
	_draw_waterfall()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("boats"):
		_track_boat_in_water(body)

		var landing_angle := get_landing_angle_degrees(body)
		boat_entered.emit(body)
		_apply_entry_impulse(body)

		if landing_angle > safe_landing_angle_degrees:
			if body.has_method("lose_crew"):
				body.lose_crew(unsafe_landing_crew_loss)
			boat_bad_landing.emit(body, landing_angle)
		else:
			boat_landed_safely.emit(body, landing_angle)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("boats"):
		_untrack_boat_in_water(body)
		boat_exited.emit(body)


## Returns the boat's absolute global rotation, normalized to 0-180 degrees.
func get_landing_angle_degrees(body: Node2D) -> float:
	var normalized_rotation := wrapf(body.global_rotation, -PI, PI)
	return absf(rad_to_deg(normalized_rotation))


## Returns how far a global point is below the animated surface.
## Negative values mean the point is above the current water surface.
func get_surface_depth_at_global_position(global_position: Vector2) -> float:
	var local_position := to_local(global_position)
	return local_position.y - _sample_surface_y(local_position.x)


## Returns the water's global upward direction after node rotation.
func get_water_up_direction() -> Vector2:
	return global_transform.basis_xform(Vector2.UP).normalized()


## Returns the water's global flow direction after node rotation.
func get_water_flow_direction() -> Vector2:
	return global_transform.basis_xform(Vector2.RIGHT).normalized()


## Returns the waterfall drop direction in this node's local drawing space.
func get_waterfall_drop_direction() -> Vector2:
	return global_transform.basis_xform_inv(Vector2.DOWN).normalized()


## Returns the global rotation boats should settle toward while floating here.
func get_boat_target_rotation() -> float:
	return global_rotation


## Returns the force/impulse multiplier needed to preserve tuned acceleration for this body mass.
func get_mass_force_scale(rigid_body: RigidBody2D) -> float:
	if reference_boat_mass <= 0.0:
		return 1.0

	return maxf(rigid_body.mass / reference_boat_mass, 0.0)


func _apply_entry_impulse(body: Node2D) -> void:
	if body is RigidBody2D:
		var rigid_body := body as RigidBody2D
		var mass_force_scale := get_mass_force_scale(rigid_body)
		rigid_body.apply_central_impulse(
			(
				get_water_flow_direction() * current_flow_speed
				+ get_water_up_direction() * fountain_impulse
			) * mass_force_scale
		)


func _apply_buoyancy_to_boat(boat: Node2D) -> void:
	if not boat is RigidBody2D:
		return

	var surface_depth := get_surface_depth_at_global_position(boat.global_position)
	if surface_depth <= 0.0:
		return

	var rigid_boat := boat as RigidBody2D
	var water_up_direction := get_water_up_direction()
	var water_flow_direction := get_water_flow_direction()
	var local_position := to_local(boat.global_position)
	var submerged_ratio := clampf(surface_depth / target_float_depth, 0.0, 1.0)
	var upward_speed := rigid_boat.linear_velocity.dot(water_up_direction)
	var mass_force_scale := get_mass_force_scale(rigid_boat)
	var damping_force := maxf(-upward_speed * buoyancy_damping * reference_boat_mass, 0.0)
	var float_force := minf(buoyancy_force * submerged_ratio + damping_force, max_buoyancy_force)
	var edge_down_force := 0.0
	if _is_in_waterfall_edge(local_position):
		edge_down_force = waterfall_down_force * mass_force_scale

	rigid_boat.sleeping = false
	rigid_boat.apply_central_force(water_up_direction * float_force * mass_force_scale)
	rigid_boat.apply_central_force(water_flow_direction * current_force * mass_force_scale)
	rigid_boat.apply_central_force(-water_up_direction * edge_down_force)
	_apply_stability_to_boat(rigid_boat, submerged_ratio, mass_force_scale)


func _refresh_overlapping_boats() -> void:
	_boats_in_water = _boats_in_water.filter(func(boat: Node2D) -> bool:
		return is_instance_valid(boat) and boat.is_in_group("boats")
	)

	for body in get_overlapping_bodies():
		if body.is_in_group("boats") and not _boats_in_water.has(body):
			_track_boat_in_water(body)


func _track_boat_in_water(body: Node2D) -> void:
	if _boats_in_water.has(body):
		return

	_boats_in_water.append(body)
	if body.has_method("enter_water"):
		body.enter_water()


func _untrack_boat_in_water(body: Node2D) -> void:
	if not _boats_in_water.has(body):
		return

	_boats_in_water.erase(body)
	if body.has_method("exit_water"):
		body.exit_water()


func _apply_stability_to_boat(rigid_boat: RigidBody2D, submerged_ratio: float, mass_force_scale: float) -> void:
	if submerged_ratio < water_stability_min_submerged_ratio:
		return

	var rotation_error := wrapf(rigid_boat.global_rotation - get_boat_target_rotation(), -PI, PI)
	var desired_angular_velocity := clampf(-rotation_error * angular_recovery_speed, -max_water_angular_velocity, max_water_angular_velocity)
	var stability_blend := clampf(angular_stability_blend * submerged_ratio, 0.0, 1.0)
	rigid_boat.angular_velocity = lerpf(rigid_boat.angular_velocity, desired_angular_velocity, stability_blend)

	var stability_torque := (
		-rotation_error * angular_stability_torque
		- rigid_boat.angular_velocity * angular_damping_torque
	) * submerged_ratio * mass_force_scale
	rigid_boat.apply_torque(stability_torque)


func _is_in_waterfall_edge(local_position: Vector2) -> bool:
	if not enable_waterfall:
		return false

	var side := signi(waterfall_side)
	if side == 0:
		side = 1

	var edge_x := water_width * 0.5 * float(side)
	var distance_from_edge := (local_position.x - edge_x) * float(side)
	var is_in_edge_strip := distance_from_edge >= 0.0 and distance_from_edge <= waterfall_width
	var is_near_surface := local_position.y >= _sample_surface_y(local_position.x) - wave_amplitude
	return is_in_edge_strip and is_near_surface


func _sync_collision_shape() -> void:
	if collision_shape.shape is RectangleShape2D:
		var rectangle := collision_shape.shape as RectangleShape2D
		var extra_height := waterfall_height if enable_waterfall else 0.0
		rectangle.size = Vector2(water_width, water_depth + wave_amplitude * 2.0 + extra_height)
		collision_shape.position = Vector2(0.0, surface_y + (water_depth + extra_height) * 0.5)


func _build_surface_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var segment_count := 72
	var left := -water_width * 0.5

	for index in range(segment_count + 1):
		var progress := float(index) / float(segment_count)
		var x := left + water_width * progress
		points.append(Vector2(x, _sample_surface_y(x)))

	return points


func _sample_surface_y(x: float) -> float:
	var primary := sin(x * wave_frequency + _time * current_flow_speed * 0.03) * wave_amplitude
	var secondary := sin(x * secondary_wave_frequency - _time * current_flow_speed * 0.045) * secondary_wave_amplitude
	return surface_y + primary + secondary


func _draw_flow_lines() -> void:
	var left := -water_width * 0.5
	var line_count := 12

	for index in range(line_count):
		var lane_progress := float(index + 1) / float(line_count + 1)
		var y := surface_y + water_depth * lane_progress
		var offset := fposmod(_time * current_flow_speed + float(index * 113), water_width + 120.0)
		var x := left - 60.0 + offset
		var start := Vector2(x - 42.0, y + sin(_time * 2.0 + index) * 3.0)
		var end := Vector2(x + 42.0, y + sin(_time * 2.0 + index + 0.8) * 3.0)
		draw_line(start, end, Color(0.72, 0.9, 1.0, 0.34), 2.0)


func _draw_waterfall() -> void:
	if not enable_waterfall:
		return

	var side := signi(waterfall_side)
	if side == 0:
		side = 1

	var water_flow_direction := Vector2(float(side), 0.0)
	var drop_direction := get_waterfall_drop_direction()
	var edge_point := Vector2(water_width * 0.5 * float(side), _sample_surface_y(water_width * 0.5 * float(side)))
	var lip_end := edge_point + water_flow_direction * waterfall_lip_length + drop_direction * wave_amplitude * 0.35
	var curtain_outer_top := lip_end + water_flow_direction * waterfall_width
	var curtain_outer_bottom := curtain_outer_top + drop_direction * waterfall_height
	var curtain_inner_bottom := lip_end + drop_direction * (waterfall_height - waterfall_height * 0.14)
	var curtain_points := PackedVector2Array([
		lip_end,
		curtain_outer_top,
		curtain_outer_bottom,
		curtain_inner_bottom,
	])
	var lip_points := _build_waterfall_lip_points(edge_point, lip_end)

	draw_colored_polygon(lip_points, water_color)
	draw_colored_polygon(curtain_points, Color(0.13, 0.56, 0.82, 0.62))
	draw_polyline(lip_points.slice(0, 7), foam_color, 3.0)

	var strand_count := 10
	for index in range(strand_count):
		var progress := float(index) / float(maxi(strand_count - 1, 1))
		var top := lip_end.lerp(curtain_outer_top, progress)
		var phase := _time * current_flow_speed * 0.08 + float(index)
		var sway := water_flow_direction * sin(phase) * 5.0
		draw_line(
			top + drop_direction * fposmod(phase * 12.0, 18.0),
			top + drop_direction * (waterfall_height - 8.0) + sway,
			Color(0.72, 0.92, 1.0, 0.55),
			2.0
		)

	_draw_waterfall_splash((curtain_outer_bottom + curtain_inner_bottom) * 0.5)


func _build_waterfall_lip_points(edge_point: Vector2, lip_end: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var bottom_offset := Vector2(0.0, water_depth * 0.18)
	var curve_segments := 6

	for index in range(curve_segments + 1):
		var t := float(index) / float(curve_segments)
		var eased_t := t * t * (3.0 - 2.0 * t)
		var point := edge_point.lerp(lip_end, t)
		point.y += sin(eased_t * PI) * wave_amplitude * 0.45
		points.append(point)

	for index in range(curve_segments, -1, -1):
		var t := float(index) / float(curve_segments)
		var point := edge_point.lerp(lip_end, t) + bottom_offset
		points.append(point)

	return points


func _draw_waterfall_splash(center: Vector2) -> void:
	var arc_count := 5
	for index in range(arc_count):
		var radius := 14.0 + float(index) * 9.0
		var alpha := 0.55 - float(index) * 0.07
		draw_arc(
			center + Vector2(sin(_time * 3.0 + index) * 4.0, 0.0),
			radius,
			PI,
			TAU,
			18,
			Color(0.82, 0.96, 1.0, alpha),
			2.0
		)
