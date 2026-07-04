class_name GameCamera
extends Camera2D

@export var camera_offset: Vector2 = Vector2(0, -150)
@export var zoom_level: Vector2 = Vector2(1.3, 1.3)

var _player: Node2D


func _ready() -> void:
	top_level = true
	zoom = zoom_level


func _process(_delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("boats")
		if not _player:
			return
	global_position = _player.global_position + camera_offset
