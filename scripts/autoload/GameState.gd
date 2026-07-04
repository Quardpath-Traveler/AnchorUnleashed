extends Node

signal score_changed(score: int)
signal coin_changed(coin: int)
signal rescued_changed(count: int, target: int)
signal pause_changed(is_paused: bool)

var score: int = 0
var coin: int = 0
var rescued_count: int = 0
var rescued_target: int = 0
var is_paused: bool = false
var current_level_scene: String = ""


func reset() -> void:
	score = 0
	coin = 0
	rescued_count = 0
	rescued_target = 0
	set_paused(false)
	score_changed.emit(score)
	coin_changed.emit(coin)
	rescued_changed.emit(rescued_count, rescued_target)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func add_coin(amount: int) -> void:
	coin += amount
	coin_changed.emit(coin)


func set_coin(value: int) -> void:
	coin = value
	coin_changed.emit(coin)


func set_rescued_target(value: int) -> void:
	rescued_target = value
	rescued_changed.emit(rescued_count, rescued_target)


func set_rescued_count(value: int) -> void:
	rescued_count = value
	rescued_changed.emit(rescued_count, rescued_target)


func add_rescued(amount: int = 1) -> void:
	rescued_count += amount
	rescued_changed.emit(rescued_count, rescued_target)


func set_paused(value: bool) -> void:
	if is_paused == value:
		return

	is_paused = value
	get_tree().paused = is_paused
	pause_changed.emit(is_paused)
