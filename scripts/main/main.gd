extends Node

const GAME_SCENE := preload("res://scenes/game/Game.tscn")


func _ready() -> void:
	var game := GAME_SCENE.instantiate()
	add_child(game)
