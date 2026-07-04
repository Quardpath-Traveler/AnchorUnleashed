class_name SlopeWithWater
extends StaticBody2D

## Length of the sloped top surface in local space.
@export var slope_length: float = 560.0:
	set(value):
		slope_length = maxf(value, 1.0)
		if is_node_ready():
			_rebuild_slope()

## Inclination of the slope in degrees. Positive tilts downward to the right.
@export_range(-60.0, 60.0, 0.1) var slope_angle_degrees: float = 14.0:
	set(value):
		slope_angle_degrees = clampf(value, -60.0, 60.0)
		if is_node_ready():
			_rebuild_slope()

## Thickness of the solid ground below the sloped surface.
@export var slope_thickness: float = 70.0:
	set(value):
		slope_thickness = maxf(value, 1.0)
		if is_node_ready():
			_rebuild_slope()

## Fill color for the slope polygon.
@export var slope_color: Color = Color(0.46, 0.38, 0.28, 1.0):
	set(value):
		slope_color = value
		if is_node_ready():
			_update_visual_color()

## Width of the water surface, should match slope_length in most cases.
@export var water_width: float = 560.0:
	set(value):
		water_width = value
		if is_node_ready():
			_sync_water_surface()

## Vertical depth of the water body below the animated surface.
@export var water_depth: float = 72.0:
	set(value):
		water_depth = value
		if is_node_ready():
			_sync_water_surface()

## Baseline local Y coordinate used as the center line for surface waves.
@export var surface_y: float = -36.0:
	set(value):
		surface_y = value
		if is_node_ready():
			_sync_water_surface()

## Height of the primary animated surface wave.
@export var wave_amplitude: float = 9.0:
	set(value):
		wave_amplitude = value
		if is_node_ready():
			_sync_water_surface()

## Height of the secondary animated surface wave.
@export var secondary_wave_amplitude: float = 4.0:
	set(value):
		secondary_wave_amplitude = value
		if is_node_ready():
			_sync_water_surface()

## Visual flow speed and entry impulse strength along the water direction.
@export var current_flow_speed: float = 220.0:
	set(value):
		current_flow_speed = value
		if is_node_ready():
			_sync_water_surface()

## Continuous force applied to floating boats along the water direction.
@export var current_force: float = 220.0:
	set(value):
		current_force = value
		if is_node_ready():
			_sync_water_surface()

## Base upward force applied to submerged boats.
@export var buoyancy_force: float = 5000.0:
	set(value):
		buoyancy_force = value
		if is_node_ready():
			_sync_water_surface()

## Upper clamp for total upward buoyancy force, including damping.
@export var max_buoyancy_force: float = 11130.0:
	set(value):
		max_buoyancy_force = value
		if is_node_ready():
			_sync_water_surface()

## Boat mass that the exported water force values were tuned against.
@export var reference_boat_mass: float = 10.0:
	set(value):
		reference_boat_mass = value
		if is_node_ready():
			_sync_water_surface()

@onready var _water_surface: WaterSurface = %WaterSurface
@onready var _visual: Polygon2D = %SlopeVisual
@onready var _collision: CollisionPolygon2D = %SlopeCollision


func _ready() -> void:
	if _water_surface == null:
		push_error("SlopeWithWater: WaterSurface child instance is missing.")
	if _visual == null:
		push_error("SlopeWithWater: SlopeVisual child node is missing.")
	if _collision == null:
		push_error("SlopeWithWater: SlopeCollision child node is missing.")

	_rebuild_slope()
	_sync_water_surface()


func _rebuild_slope() -> void:
	if _visual == null or _collision == null:
		return

	var half_length := slope_length * 0.5
	var angle_rad := deg_to_rad(slope_angle_degrees)
	var top_left := Vector2(-half_length, 0.0)
	var top_right := Vector2(half_length, 0.0)
	var down := Vector2(0.0, slope_thickness)
	var bottom_right := top_right + down.rotated(angle_rad)
	var bottom_left := top_left + down.rotated(angle_rad)

	var polygon := PackedVector2Array([top_left, top_right, bottom_right, bottom_left])
	_visual.polygon = polygon
	_collision.polygon = polygon


func _update_visual_color() -> void:
	if _visual != null:
		_visual.color = slope_color


func _sync_water_surface() -> void:
	if _water_surface == null:
		return

	_water_surface.water_width = water_width
	_water_surface.water_depth = water_depth
	_water_surface.surface_y = surface_y
	_water_surface.wave_amplitude = wave_amplitude
	_water_surface.secondary_wave_amplitude = secondary_wave_amplitude
	_water_surface.current_flow_speed = current_flow_speed
	_water_surface.current_force = current_force
	_water_surface.buoyancy_force = buoyancy_force
	_water_surface.max_buoyancy_force = max_buoyancy_force
	_water_surface.reference_boat_mass = reference_boat_mass

	_water_surface.rotation = -deg_to_rad(slope_angle_degrees)
	_water_surface.position = Vector2(0.0, -surface_y)
