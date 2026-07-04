class_name TutorialLevel
extends Node2D

signal level_completed

var player: Node2D
var _prompt_sequence_id: int = 0

@onready var start_marker: Marker2D = %StartMarker
@onready var finish_area: Area2D = %FinishArea
@onready var tutorial_prompt: TutorialPrompt = %TutorialPrompt
@onready var tutorial_triggers: Node2D = %TutorialTriggers
@onready var wave_chaser: WaveChaser = %WaveChaser


func _ready() -> void:
	finish_area.body_entered.connect(_on_finish_area_body_entered)
	_connect_tutorial_triggers()


func setup(active_player: Node2D) -> void:
	player = active_player
	wave_chaser.target = active_player


func get_start_position() -> Vector2:
	return start_marker.global_position


func _connect_tutorial_triggers() -> void:
	for child in tutorial_triggers.get_children():
		var trigger := child as TutorialTrigger
		if trigger == null:
			continue
		trigger.body_entered.connect(_on_tutorial_trigger_body_entered.bind(trigger))


func _on_tutorial_trigger_body_entered(body: Node2D, trigger: TutorialTrigger) -> void:
	if not trigger.can_trigger(body):
		return

	trigger.mark_triggered()
	_prompt_sequence_id += 1
	var prompt_sequence_id := _prompt_sequence_id
	tutorial_prompt.show_prompt(trigger.prompt_text)

	if trigger.auto_hide_seconds > 0.0:
		_hide_prompt_after(trigger.auto_hide_seconds, prompt_sequence_id)


func _hide_prompt_after(seconds: float, prompt_sequence_id: int) -> void:
	await get_tree().create_timer(seconds).timeout
	if prompt_sequence_id == _prompt_sequence_id:
		tutorial_prompt.hide_prompt()


func _on_finish_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("boats"):
		level_completed.emit()
