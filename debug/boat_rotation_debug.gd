class_name BoatRotationDebug
extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")

@export var rotation_torque_step: float = 5000.0
@export var position_locked: bool = true
@export var graph_sample_count: int = 180

@onready var _boat_container: Node2D = $BoatContainer
@onready var _value_panel: DebugValuePanel = $CanvasLayer/DebugValuePanel
@onready var _graph: DebugGraph = $CanvasLayer/DebugGraph
@onready var _indicator: DebugRotationIndicator = $DebugRotationIndicator

var _boat: Boat = null
var _initial_position: Vector2 = Vector2.ZERO
var _initial_rotation: float = 0.0

func _ready() -> void:
	_spawn_boat()
	_graph.sample_count = graph_sample_count

func _physics_process(_delta: float) -> void:
	if _boat == null or not is_instance_valid(_boat):
		return

	if position_locked:
		_boat.global_position = _initial_position
		_boat.linear_velocity = Vector2.ZERO

func _process(_delta: float) -> void:
	if _boat == null or not is_instance_valid(_boat):
		return

	var input := Input.get_axis("move_left", "move_right")
	var applied_torque := _compute_applied_torque(input)

	_value_panel.update(_boat, input, applied_torque, position_locked)
	_graph.push_sample(_boat.angular_velocity)
	_indicator.global_position = _boat.global_position
	_indicator.update(_boat, input)

func _compute_applied_torque(input: float) -> float:
	if _boat.is_airborne() and not is_zero_approx(input):
		return input * _boat.airborne_rotation_torque
	return 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_page_up"):
		_boat.airborne_rotation_torque += rotation_torque_step
	elif event.is_action_pressed("ui_page_down"):
		_boat.airborne_rotation_torque = maxf(_boat.airborne_rotation_torque - rotation_torque_step, 0.0)
	elif event.is_action_pressed("debug_reset"):
		_reset_boat()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_L:
				position_locked = not position_locked
			KEY_Q:
				get_tree().quit()

func _spawn_boat() -> void:
	if _boat != null and is_instance_valid(_boat):
		_boat.queue_free()

	_boat = BOAT_SCENE.instantiate() as Boat
	_boat_container.add_child(_boat)
	_boat.freeze = false
	_initial_position = _boat_container.global_position
	_initial_rotation = _boat.global_rotation
	_reset_boat()

func _reset_boat() -> void:
	if _boat == null or not is_instance_valid(_boat):
		return
	_boat.global_position = _initial_position
	_boat.global_rotation = _initial_rotation
	_boat.linear_velocity = Vector2.ZERO
	_boat.angular_velocity = 0.0
