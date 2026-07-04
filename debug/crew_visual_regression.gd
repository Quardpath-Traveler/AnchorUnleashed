extends Node2D

const BOAT_SCENE := preload("res://scenes/player/Boat.tscn")

var _boat: Boat
var _failures: Array[String] = []
var _finished: bool = false


func _ready() -> void:
	_boat = BOAT_SCENE.instantiate() as Boat
	_boat.posture_logging_enabled = false
	add_child(_boat)
	call_deferred("_run_checks")


func _run_checks() -> void:
	_assert_crew_visual_count(3, "initial")
	_assert_crew_visuals_use_npc_art()
	_assert_crew_visuals_are_noninteractive()
	_assert_crew_visual_scale_is_tuned()

	_boat.gain_crew(1)
	_assert_crew_visual_count(4, "after gain")

	_boat.lose_crew(2)
	_assert_crew_visual_count(2, "after loss")
	_assert_crew_members_are_centered()

	_finish()


func _assert_crew_visual_count(expected_count: int, label: String) -> void:
	var crew_visuals := _boat.get_node_or_null("CrewVisuals")
	if crew_visuals == null:
		_fail("%s: CrewVisuals node missing" % label)
		return

	var actual_count := crew_visuals.get_child_count()
	if actual_count != expected_count:
		_fail("%s: expected %d crew visuals, got %d" % [label, expected_count, actual_count])


func _assert_crew_visuals_use_npc_art() -> void:
	var crew_visuals := _boat.get_node_or_null("CrewVisuals")
	if crew_visuals == null or crew_visuals.get_child_count() == 0:
		return

	var first_member := crew_visuals.get_child(0) as Node2D
	if first_member.scene_file_path != "res://scenes/characters/BoatCrewNPC.tscn":
		_fail("Crew member should use NPC visual scene, got %s" % first_member.scene_file_path)
		return

	var sprite := first_member.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		_fail("Crew member NPC visual should contain Sprite2D")
		return
	if sprite.texture == null:
		_fail("Crew member NPC visual Sprite2D should have a texture")
		return
	if sprite.texture.resource_path != "res://assets/art/Character Art Assets/Protagonist Assets/npc.png":
		_fail("Crew member should use npc.png, got %s" % sprite.texture.resource_path)


func _assert_crew_visuals_are_noninteractive() -> void:
	var crew_visuals := _boat.get_node_or_null("CrewVisuals")
	if crew_visuals == null:
		return

	for crew_member in crew_visuals.get_children():
		if crew_member.get_script() != null:
			_fail("%s should not carry gameplay scripts" % crew_member.name)
		_assert_no_area_descendants(crew_member)


func _assert_no_area_descendants(node: Node) -> void:
	for child in node.get_children():
		if child is Area2D:
			_fail("%s should not contain Area2D descendant %s" % [node.name, child.name])
		_assert_no_area_descendants(child)


func _assert_crew_visual_scale_is_tuned() -> void:
	var crew_visuals := _boat.get_node_or_null("CrewVisuals")
	if crew_visuals == null or crew_visuals.get_child_count() == 0:
		return

	var first_member := crew_visuals.get_child(0) as Node2D
	if first_member.scale.x < 0.25 or first_member.scale.x > 0.7:
		_fail("Crew member scale should keep NPCs readable on the boat, got %v" % first_member.scale)
	if first_member.scale.y < 0.25 or first_member.scale.y > 0.7:
		_fail("Crew member scale should keep NPCs readable on the boat, got %v" % first_member.scale)


func _assert_crew_members_are_centered() -> void:
	var crew_visuals := _boat.get_node_or_null("CrewVisuals")
	if crew_visuals == null or crew_visuals.get_child_count() < 2:
		return

	var first_member := crew_visuals.get_child(0) as Node2D
	var last_member := crew_visuals.get_child(crew_visuals.get_child_count() - 1) as Node2D
	if not is_equal_approx(first_member.position.x, -last_member.position.x):
		_fail("Crew member row should be centered, got first x %.2f and last x %.2f" % [
			first_member.position.x,
			last_member.position.x,
		])


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _finished:
		return
	_finished = true

	if _failures.is_empty():
		print("PASS: Boat crew visuals track crew count.")
		get_tree().quit(0)
	else:
		print("FAIL: Boat crew visual regression failed:")
		for failure in _failures:
			print("  - %s" % failure)
		get_tree().quit(1)
