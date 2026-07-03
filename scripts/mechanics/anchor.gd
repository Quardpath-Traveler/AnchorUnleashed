class_name Anchor
extends Node2D

signal aim_started
signal launched(target_position: Vector2)
signal hooked(hook_point: Node2D)
signal recalled

enum State { READY, AIMING, FLYING, HOOKED }

@export var max_length: float = 360.0
@export var launch_speed: float = 720.0

var is_ready: bool = true
var is_aiming: bool = false
var state: State = State.READY
var throw_origin_global: Vector2
var launch_velocity: Vector2
var rope_length: float = 0.0
var attached_hook_point: Node2D

@onready var rope_line: Line2D = %RopeLine
@onready var head: Area2D = %Head


func _ready() -> void:
	head.position = Vector2.ZERO
	rope_line.visible = false
	head.area_entered.connect(_on_head_area_entered)
	_reset_to_socket()


func _physics_process(delta: float) -> void:
	match state:
		State.AIMING:
			_update_rope_visual()
		State.FLYING:
			global_position += launch_velocity * delta
			if global_position.distance_to(throw_origin_global) >= max_length:
				recall()
				return
			_update_rope_visual()
		State.HOOKED:
			if not is_instance_valid(attached_hook_point):
				recall()
				return
			global_position = attached_hook_point.global_position
			_update_rope_visual()


func start_aim() -> void:
	if state != State.READY:
		return

	throw_origin_global = _get_rope_start_global()
	state = State.AIMING
	is_aiming = true
	aim_started.emit()


func launch(target_position: Vector2) -> void:
	if state != State.AIMING or not is_ready:
		return

	throw_origin_global = _get_rope_start_global()
	var direction := throw_origin_global.direction_to(target_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT

	top_level = true
	global_position = throw_origin_global
	launch_velocity = direction * launch_speed
	rope_length = 0.0
	state = State.FLYING
	is_aiming = false
	is_ready = false
	rope_line.visible = true
	_update_rope_visual()
	launched.emit(target_position)


func attach_to(hook_point: Node2D) -> void:
	if state != State.FLYING:
		return

	attached_hook_point = hook_point
	global_position = attached_hook_point.global_position
	rope_length = minf(_get_rope_start_global().distance_to(attached_hook_point.global_position), max_length)
	state = State.HOOKED
	_update_rope_visual()
	hooked.emit(hook_point)


func recall() -> void:
	if state == State.READY:
		return

	attached_hook_point = null
	state = State.READY
	is_aiming = false
	is_ready = true
	rope_line.visible = false
	_reset_to_socket()
	recalled.emit()


func is_active() -> bool:
	return state == State.AIMING or state == State.FLYING or state == State.HOOKED


func is_hooked() -> bool:
	return state == State.HOOKED and is_instance_valid(attached_hook_point)


func get_rope_length() -> float:
	return rope_length


func get_hook_global_position() -> Vector2:
	if is_hooked():
		return attached_hook_point.global_position

	return global_position


func _on_head_area_entered(area: Area2D) -> void:
	var hook_point := area.get_parent()
	if hook_point != null and hook_point.is_in_group("hook_points"):
		attach_to(hook_point)


func _get_rope_start_global() -> Vector2:
	var parent_node := get_parent()
	if parent_node is Node2D:
		return (parent_node as Node2D).global_position

	return throw_origin_global


func _update_rope_visual() -> void:
	head.global_position = global_position
	rope_line.visible = is_active()
	rope_line.points = PackedVector2Array([
		to_local(_get_rope_start_global()),
		Vector2.ZERO,
	])


func _reset_to_socket() -> void:
	top_level = false
	position = Vector2.ZERO
	rotation = 0.0
	rope_length = 0.0
	head.position = Vector2.ZERO
	rope_line.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2.ZERO,
	])
