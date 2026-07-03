class_name ResultScreen
extends CanvasLayer

signal retry_requested
signal main_menu_requested

@onready var score_label: Label = %ScoreLabel
@onready var stats_label: Label = %StatsLabel
@onready var retry_button: Button = %RetryButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	visible = false
	retry_button.pressed.connect(retry_requested.emit)
	main_menu_button.pressed.connect(main_menu_requested.emit)


func show_results(score: int, stats: Dictionary = {}) -> void:
	score_label.text = "Score: %d" % score
	stats_label.text = str(stats)
	visible = true
