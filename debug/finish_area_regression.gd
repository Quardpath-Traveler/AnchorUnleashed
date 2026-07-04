extends Node2D

@export var timeout_seconds: float = 25.0
@export var fail_on_timeout: bool = true

@onready var _level: LevelPrototypeSlope = $Level as LevelPrototypeSlope
@onready var _boat: Boat = $Boat as Boat

var _elapsed: float = 0.0
var _completed: bool = false


func _ready() -> void:
	GameState.current_level_scene = "res://debug/FinishAreaRegression.tscn"
	_boat.global_position = _level.get_start_position()
	_level.level_completed.connect(_on_level_completed)


func _physics_process(delta: float) -> void:
	if _completed:
		return

	_elapsed += delta
	if _elapsed >= timeout_seconds:
		_finish(false, "timeout")


func _on_level_completed() -> void:
	_finish(true, "level_completed")


func _finish(success: bool, reason: String) -> void:
	if _completed:
		return

	_completed = true
	set_physics_process(false)

	print(
		"FINISH_AREA_RESULT %s"
		% JSON.stringify(
			{
				"success": success,
				"reason": reason,
				"elapsed_seconds": snappedf(_elapsed, 0.001),
				"boat_position": {
					"x": snappedf(_boat.global_position.x, 0.001),
					"y": snappedf(_boat.global_position.y, 0.001),
				},
			}
		)
	)

	if success:
		EventBus.game_completed.emit()
	elif fail_on_timeout:
		get_tree().quit(1)
	else:
		get_tree().quit()
