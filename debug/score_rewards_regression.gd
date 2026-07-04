extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")
const CAN_COLLECTIBLE_SCENE := preload("res://scenes/items/CanCollectible.tscn")
const NPC_SCENE := preload("res://scenes/characters/NPC.tscn")

var _boat: Boat
var _failures: Array[String] = []
var _finished: bool = false


func _ready() -> void:
	GameState.reset()
	_boat = BOAT_SCENE.instantiate() as Boat
	_boat.posture_logging_enabled = false
	add_child(_boat)
	call_deferred("_run_checks")


func _run_checks() -> void:
	await _check_pickup_reward()
	await _check_rescue_reward()
	await _check_full_crew_does_not_consume_rescue()
	_check_airborne_trick_tracking_reward()
	_check_bad_landing_does_not_award_trick()
	_check_no_pending_trick_does_not_award()
	_finish()


func _check_pickup_reward() -> void:
	var collectible := CAN_COLLECTIBLE_SCENE.instantiate() as CanCollectible
	add_child(collectible)

	collectible.body_entered.emit(_boat)
	_assert_equal(GameState.coin, 1, "coin after pickup")
	_assert_equal(GameState.score, GameState.COIN_SCORE_VALUE, "score after pickup")
	_assert_true(collectible.is_queued_for_deletion(), "collectible queues free after pickup")

	await get_tree().process_frame
	_assert_true(not is_instance_valid(collectible), "collectible frees after pickup frame")


func _check_rescue_reward() -> void:
	var npc := NPC_SCENE.instantiate() as Node2D
	add_child(npc)
	var rescue_area := npc.get_node_or_null("RescueArea") as NPCRescue
	if rescue_area == null:
		_fail("NPC RescueArea is missing or not an NPCRescue")
		return

	var rescue_value := rescue_area.rescue_value
	var previous_crew_count := _boat.crew_count
	var expected_crew_count := mini(previous_crew_count + rescue_value, _boat.max_crew_count)

	rescue_area.body_entered.emit(_boat)
	await get_tree().process_frame

	_assert_equal(_boat.crew_count, expected_crew_count, "crew after rescue")
	_assert_equal(GameState.rescued_count, rescue_value, "rescued count after rescue")
	_assert_equal(
		GameState.score,
		GameState.COIN_SCORE_VALUE + GameState.RESCUE_SCORE_VALUE,
		"score after rescue"
	)
	_assert_true(not is_instance_valid(npc), "rescued NPC frees after rescue frame")


func _check_full_crew_does_not_consume_rescue() -> void:
	_boat.crew_count = _boat.max_crew_count
	var previous_rescued_count := GameState.rescued_count
	var previous_score := GameState.score

	var npc := NPC_SCENE.instantiate() as Node2D
	add_child(npc)
	var rescue_area := npc.get_node_or_null("RescueArea") as NPCRescue
	if rescue_area == null:
		_fail("full crew NPC RescueArea is missing or not an NPCRescue")
		return

	var rescue_value := rescue_area.rescue_value
	rescue_area.body_entered.emit(_boat)
	await get_tree().process_frame

	_assert_equal(_boat.crew_count, _boat.max_crew_count, "crew remains full after blocked rescue")
	_assert_equal(
		GameState.rescued_count,
		previous_rescued_count,
		"rescued count unchanged after blocked full-crew rescue"
	)
	_assert_equal(GameState.score, previous_score, "score unchanged after blocked full-crew rescue")
	_assert_true(is_instance_valid(npc), "full-crew blocked NPC remains valid")

	if not is_instance_valid(npc):
		return

	_boat.crew_count = _boat.max_crew_count - 1
	rescue_area.body_entered.emit(_boat)
	await get_tree().process_frame

	_assert_equal(_boat.crew_count, _boat.max_crew_count, "crew fills after retry rescue")
	_assert_equal(
		GameState.rescued_count,
		previous_rescued_count + rescue_value,
		"rescued count after retry rescue"
	)
	_assert_equal(
		GameState.score,
		previous_score + rescue_value * GameState.RESCUE_SCORE_VALUE,
		"score after retry rescue"
	)
	_assert_true(not is_instance_valid(npc), "retry rescued NPC frees after rescue frame")


func _check_airborne_trick_tracking_reward() -> void:
	var previous_score := GameState.score

	_prepare_airborne_trick_tracking()
	_boat.global_rotation = TAU - 0.01
	_boat._update_airborne_trick_tracking()
	_boat.on_safe_landing(0.0, self)

	_assert_equal(GameState.score, previous_score, "partial airborne rotation does not award")

	_prepare_airborne_trick_tracking()
	for rotation in [PI * 0.75, PI * 1.5, PI * 2.0]:
		_boat.global_rotation = rotation
		_boat._update_airborne_trick_tracking()
	_boat.on_safe_landing(0.0, self)

	_assert_equal(
		GameState.score,
		previous_score + GameState.TRICK_360_SCORE_VALUE,
		"full airborne rotation awards on safe landing"
	)

	_boat.on_safe_landing(0.0, self)
	_assert_equal(
		GameState.score,
		previous_score + GameState.TRICK_360_SCORE_VALUE,
		"safe landing does not award after tracked trick resets"
	)


func _prepare_airborne_trick_tracking() -> void:
	_boat.global_rotation = 0.0
	_boat._contact_count = 0
	_boat._water_contact_count = 0
	_boat._was_tracking_airborne_trick = true
	_boat._last_trick_rotation = 0.0
	_boat._airborne_rotation_total = 0.0
	_boat._pending_360_tricks = 0


func _check_bad_landing_does_not_award_trick() -> void:
	var previous_score := GameState.score
	_boat._pending_360_tricks = 1
	_boat.on_bad_landing(90.0, 0.0, self)

	_assert_equal(GameState.score, previous_score, "bad landing does not award pending trick")
	_boat.on_safe_landing(0.0, self)
	_assert_equal(
		GameState.score,
		previous_score,
		"safe landing after bad landing does not award cleared pending trick"
	)


func _check_no_pending_trick_does_not_award() -> void:
	var previous_score := GameState.score
	_boat._pending_360_tricks = 0
	_boat.on_safe_landing(0.0, self)

	_assert_equal(GameState.score, previous_score, "safe landing without pending trick does not award")


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		_fail("%s: expected %s, got %s" % [label, expected, actual])


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _finished:
		return
	_finished = true

	if _failures.is_empty():
		print("PASS: Score rewards runtime regression passed.")
		get_tree().quit(0)
	else:
		print("FAIL: Score rewards runtime regression failed:")
		for failure in _failures:
			print("  - %s" % failure)
		get_tree().quit(1)
