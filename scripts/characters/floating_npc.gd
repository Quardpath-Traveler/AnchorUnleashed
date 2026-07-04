class_name FloatingNPC
extends Node2D

## Multiplier applied to the water's current_flow_speed to determine drift speed.
@export var drift_speed_multiplier: float = 0.6
## Local offset applied to the surface height so the sprite base sits on the water.
@export var vertical_offset: float = 0.0
## Area2D used to detect overlapping WaterSurface instances.
@export var detection_area: Area2D
## Sprite to flip based on drift direction.
@export var sprite: Sprite2D

var _current_water: WaterSurface = null

func _ready() -> void:
	if detection_area == null:
		push_error("FloatingNPC: detection_area is not assigned on %s" % name)
	if sprite == null:
		push_error("FloatingNPC: sprite is not assigned on %s" % name)


func _physics_process(_delta: float) -> void:
	_update_current_water()
	if _current_water == null:
		return

	_align_to_surface()
	_drift_with_current(_delta)
	_update_facing()


func _update_current_water() -> void:
	if detection_area == null:
		_current_water = null
		return

	for area in detection_area.get_overlapping_areas():
		if area is WaterSurface:
			_current_water = area
			return

	_current_water = null


func _align_to_surface() -> void:
	var surface_height := _current_water.get_surface_height_at_global_position(global_position)
	global_position.y = surface_height + vertical_offset


func _drift_with_current(delta: float) -> void:
	var flow_direction := _current_water.get_water_flow_direction()
	var drift_speed := _current_water.current_flow_speed * drift_speed_multiplier
	global_position += flow_direction * drift_speed * delta


func _update_facing() -> void:
	if sprite == null:
		return
	var flow_direction := _current_water.get_water_flow_direction()
	if flow_direction.x < 0.0:
		sprite.flip_h = true
	elif flow_direction.x > 0.0:
		sprite.flip_h = false
