class_name Boatman
extends Node2D

enum AimSpinDirection { CLOCKWISE = 1, COUNTERCLOCKWISE = -1 }

@export_range(0.0, 30.0, 0.1) var hand_rotation_blend_rate: float = 12.0
@export var default_hand_rotation: float = 0.0
@export var aim_spin_direction: AimSpinDirection = AimSpinDirection.CLOCKWISE
@export_range(0.0, 30.0, 0.1, "radians") var aim_spin_speed: float = TAU * 1.5

@onready var hand_pivot: Node2D = %HandPivot
@onready var hand_sprite: Sprite2D = get_node_or_null("HandPivot/HandSprite") as Sprite2D
@onready var hand_point: Marker2D = get_node_or_null("HandPivot/HandSprite/HandPoint") as Marker2D
@onready var anchor: Anchor = get_node_or_null("HandPivot/Anchor") as Anchor

var _aiming: bool = false
var _base_arm_angle: float = 0.0
var _aim_spin_angle: float = 0.0


func _ready() -> void:
	_calibrate_arm()

	if anchor != null:
		anchor.aim_started.connect(_on_aim_started)
		anchor.launched.connect(_on_anchor_launched)
		anchor.hooked.connect(_on_anchor_hooked)
		anchor.recalled.connect(_on_anchor_no_longer_aiming)


func _process(delta: float) -> void:
	var target := default_hand_rotation
	if _aiming and anchor != null:
		_aim_spin_angle += aim_spin_direction * aim_spin_speed * delta
		target = _aim_spin_angle
	var weight: float = clampf(hand_rotation_blend_rate * delta, 0.0, 1.0)
	hand_pivot.rotation = lerp_angle(hand_pivot.rotation, target, weight)


func get_arm_global_direction() -> Vector2:
	return Vector2.from_angle(hand_pivot.global_rotation + _base_arm_angle)


func get_base_arm_angle() -> float:
	return _base_arm_angle


func _calibrate_arm() -> void:
	if hand_point == null or hand_sprite == null or anchor == null:
		return

	# HandPoint's position relative to HandPivot (accounting for HandSprite scale).
	# At _ready() time HandPivot.rotation == 0, so this is the base arm direction.
	var hand_point_local := hand_pivot.to_local(hand_point.global_position)
	_base_arm_angle = hand_point_local.angle()

	# Anchor rests at the hand position, rotated 90° from arm (逆时针).
	anchor.socket_offset = hand_point_local
	anchor.socket_rotation = _base_arm_angle
	anchor._reset_to_socket()


func _on_aim_started() -> void:
	_aiming = true
	_aim_spin_angle = hand_pivot.rotation


func _on_anchor_hooked(_hook_point: Node2D) -> void:
	_aiming = false


func _on_anchor_launched(_target_position: Vector2) -> void:
	_aiming = false


func _on_anchor_no_longer_aiming() -> void:
	_aiming = false
