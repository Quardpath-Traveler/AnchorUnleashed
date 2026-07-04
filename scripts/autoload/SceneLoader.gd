extends Node


const TRANSITION_OVERLAY_SCENE := preload("res://scenes/ui/TransitionOverlay.tscn")

var _transition_overlay: CanvasLayer
var _is_transitioning: bool = false


func _ready() -> void:
	EventBus.scene_transition_requested.connect(change_scene)
	EventBus.game_over_requested.connect(_on_game_over)
	EventBus.game_completed.connect(_on_game_completed)

	_transition_overlay = TRANSITION_OVERLAY_SCENE.instantiate()
	add_child(_transition_overlay)


func change_scene(scene_path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_perform_transition(scene_path, false)


func reload_scene() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_perform_transition("", true)


func _perform_transition(scene_path: String, is_reload: bool) -> void:
	get_tree().paused = true

	Engine.time_scale = 1.0

	_transition_overlay.play_enter()
	await _transition_overlay.enter_complete

	if is_reload:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame

	get_tree().paused = true

	_transition_overlay.play_exit()
	await _transition_overlay.exit_complete

	get_tree().paused = false
	_is_transitioning = false


func _on_game_over() -> void:
	change_scene("res://scenes/ui/ResultScreen.tscn")


func _on_game_completed() -> void:
	change_scene("res://scenes/ui/ResultScreen.tscn")
