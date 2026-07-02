extends CanvasLayer

@onready var score_label: Label = %ScoreLabel
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.pause_changed.connect(_on_pause_changed)
	_on_score_changed(GameState.score)
	_on_pause_changed(GameState.is_paused)


func _on_score_changed(score: int) -> void:
	score_label.text = "Score: %s" % score


func _on_pause_changed(is_paused: bool) -> void:
	status_label.text = "Paused" if is_paused else "Running"
