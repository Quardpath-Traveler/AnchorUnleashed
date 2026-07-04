extends Node2D

const EXPECTED_ZOOM := Vector2(1.15, 1.15)
const BASE_OFFSET := Vector2(0.0, -150.0)

var _boat: RigidBody2D
var _camera: GameCamera


func _ready() -> void:
	_boat = RigidBody2D.new()
	_boat.add_to_group("boats")
	_boat.global_position = Vector2(100.0, 200.0)
	add_child(_boat)

	_camera = GameCamera.new()
	add_child(_camera)

	call_deferred("_run")


func _run() -> void:
	_camera._process(0.016)
	if not _camera.zoom.is_equal_approx(EXPECTED_ZOOM):
		_fail("zoom should be pulled back to %s, got %s" % [EXPECTED_ZOOM, _camera.zoom])
		return

	_boat.linear_velocity = Vector2(1000.0, 0.0)
	_camera._process(0.1)
	var first_offset := _camera.global_position - _boat.global_position - BASE_OFFSET
	if first_offset.x <= 0.0:
		_fail("camera should look ahead in the boat velocity direction, got %s" % first_offset)
		return
	if first_offset.x >= _camera.velocity_lead_max_distance:
		_fail("camera velocity lead should transition smoothly, got %s" % first_offset)
		return
	if absf(first_offset.y) > 0.001:
		_fail("horizontal velocity should not add vertical camera lead, got %s" % first_offset)
		return

	for i in range(30):
		_camera._process(0.1)
	var settled_offset := _camera.global_position - _boat.global_position - BASE_OFFSET
	if settled_offset.x < _camera.velocity_lead_max_distance * 0.95:
		_fail("camera should settle near max velocity lead, got %s" % settled_offset)
		return

	_boat.linear_velocity = Vector2.ZERO
	_camera._process(0.1)
	var decay_offset := _camera.global_position - _boat.global_position - BASE_OFFSET
	if decay_offset.x >= settled_offset.x:
		_fail("camera velocity lead should decay when the boat slows, got %s" % decay_offset)
		return

	print("GAME_CAMERA_RESULT %s" % JSON.stringify({"success": true}))
	get_tree().quit()


func _fail(reason: String) -> void:
	print("GAME_CAMERA_RESULT %s" % JSON.stringify({"success": false, "reason": reason}))
	get_tree().quit(1)
