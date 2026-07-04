extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")
const NPC_SCENE := preload("res://scenes/characters/NPC.tscn")

@export var timeout_seconds: float = 1.0

var _boat: Boat
var _npc: Node2D
var _elapsed: float = 0.0
var _exit_code: int = 1
var _finished: bool = false


func _ready() -> void:
	_boat = BOAT_SCENE.instantiate() as Boat
	_boat.global_position = Vector2.ZERO
	_boat.posture_logging_enabled = false
	add_child(_boat)

	_npc = NPC_SCENE.instantiate() as Node2D
	_npc.global_position = Vector2.ZERO
	add_child(_npc)


func _physics_process(delta: float) -> void:
	if _finished:
		return

	_elapsed += delta
	if _boat.crew_count == 4 and not is_instance_valid(_npc):
		_pass()
		return

	if _elapsed >= timeout_seconds:
		_fail()


func _pass() -> void:
	_finished = true
	_exit_code = 0
	print("PASS: NPC rescue increments crew and consumes NPC.")
	get_tree().quit(_exit_code)


func _fail() -> void:
	_finished = true
	var npc_state := "valid" if is_instance_valid(_npc) else "freed"
	print("FAIL: NPC rescue did not complete. crew=%d npc=%s" % [_boat.crew_count, npc_state])
	get_tree().quit(_exit_code)
