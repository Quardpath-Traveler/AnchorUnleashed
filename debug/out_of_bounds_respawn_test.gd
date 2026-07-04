extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")
const DEATH_ZONE_SCENE := preload("res://scenes/mechanics/DeathZone.tscn")
const WATER_SURFACE_SCENE := preload("res://scenes/level_parts/WaterSurface.tscn")

enum Phase {
	SETUP,
	ASSERT_TRIGGER,
	ASSERT_RECOVER,
	DONE,
}

@export var launch_timeout_seconds: float = 0.5
@export var recover_timeout_seconds: float = 3.0
@export var position_tolerance: float = 16.0
@export var respawn_speed_tolerance: float = 0.01

var _phase: Phase = Phase.SETUP
var _phase_timer: float = 0.0
var _boat: Boat
var _death_zone: DeathZone
var _respawn_marker: Marker2D
var _failures: Array[String] = []
var _exit_code: int = 0
var _minimum_respawn_distance: float = INF
var _minimum_respawn_speed: float = INF
var _original_gravity_scale: float = 1.0


func _ready() -> void:
	var water := WATER_SURFACE_SCENE.instantiate() as WaterSurface
	water.global_position = Vector2(400, 400)
	water.water_width = 600.0
	water.water_depth = 120.0
	water.enable_waterfall = false
	add_child(water)

	_respawn_marker = Marker2D.new()
	_respawn_marker.global_position = Vector2(400, 300)
	add_child(_respawn_marker)

	_death_zone = DEATH_ZONE_SCENE.instantiate() as DeathZone
	_death_zone.global_position = Vector2(400, 650)
	_death_zone.respawn_marker = _respawn_marker
	add_child(_death_zone)

	_boat = BOAT_SCENE.instantiate() as Boat
	_boat.global_position = Vector2(400, 560)
	_boat.posture_logging_enabled = false
	add_child(_boat)


func _physics_process(delta: float) -> void:
	_phase_timer += delta

	match _phase:
		Phase.SETUP:
			if _boat.crew_count != 3:
				_fail("Initial crew count should be 3, got %d" % _boat.crew_count)
			_original_gravity_scale = _boat.gravity_scale
			_boat.gravity_scale = 0.0
			_boat.global_position = Vector2(400, 650)
			_phase = Phase.ASSERT_TRIGGER
			_phase_timer = 0.0

		Phase.ASSERT_TRIGGER:
			_minimum_respawn_distance = minf(
				_minimum_respawn_distance,
				_boat.global_position.distance_to(_respawn_marker.global_position)
			)
			if _boat.global_position.distance_to(_respawn_marker.global_position) <= position_tolerance:
				_minimum_respawn_speed = minf(_minimum_respawn_speed, _boat.linear_velocity.length())
			if _phase_timer < launch_timeout_seconds:
				return
			if _boat.crew_count != 2:
				_fail("Crew count should drop to 2, got %d" % _boat.crew_count)
			if _minimum_respawn_distance > position_tolerance:
				_fail("Boat did not teleport near respawn marker, got minimum distance %.2f" % _minimum_respawn_distance)
			if _minimum_respawn_speed > respawn_speed_tolerance:
				_fail("Boat respawn speed should be zero, got minimum speed %.2f" % _minimum_respawn_speed)
			if not _boat.is_respawning():
				_fail("Boat should still be in respawn state immediately after launch")
			_boat.gravity_scale = _original_gravity_scale
			_phase = Phase.ASSERT_RECOVER
			_phase_timer = 0.0

		Phase.ASSERT_RECOVER:
			if _phase_timer > recover_timeout_seconds:
				_fail("Boat did not land and exit respawn state within timeout")
				_finish()
				return
			if not _boat.is_respawning():
				_phase = Phase.DONE
				_finish()
				return

		Phase.DONE:
			_finish()


func _fail(message: String) -> void:
	_failures.append(message)
	_exit_code = 1


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: Out-of-bounds respawn works.")
	else:
		print("FAIL: Out-of-bounds respawn test failed:")
		for message in _failures:
			print("  - %s" % message)
	get_tree().quit(_exit_code)
