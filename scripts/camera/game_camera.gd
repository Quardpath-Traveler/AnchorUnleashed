class_name GameCamera
extends Camera2D

@export var camera_offset: Vector2 = Vector2(0, -150)
@export var zoom_level: Vector2 = Vector2(1.15, 1.15)
@export var velocity_lead_max_distance: float = 220.0
@export var velocity_lead_full_speed: float = 1000.0
@export var velocity_lead_min_speed: float = 25.0
@export var velocity_lead_smoothing: float = 4.0

var _player: Node2D
var _velocity_lead_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	top_level = true
	zoom = zoom_level


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("boats")
		if not _player:
			return

	var target_lead_offset := _get_velocity_lead_offset()
	var lead_weight := 1.0 - exp(-velocity_lead_smoothing * delta)
	_velocity_lead_offset = _velocity_lead_offset.lerp(target_lead_offset, lead_weight)
	global_position = _player.global_position + camera_offset + _velocity_lead_offset


func _get_velocity_lead_offset() -> Vector2:
	if not _player is RigidBody2D:
		return Vector2.ZERO

	var velocity := (_player as RigidBody2D).linear_velocity
	var speed := velocity.length()
	if speed <= velocity_lead_min_speed:
		return Vector2.ZERO

	var speed_range := maxf(velocity_lead_full_speed - velocity_lead_min_speed, 1.0)
	var lead_ratio := clampf((speed - velocity_lead_min_speed) / speed_range, 0.0, 1.0)
	return velocity.normalized() * velocity_lead_max_distance * lead_ratio
