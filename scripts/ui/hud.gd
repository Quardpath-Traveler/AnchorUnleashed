extends CanvasLayer

@onready var score_label: Label = %ScoreLabel
@onready var coin_label: Label = %CoinLabel
@onready var rescued_label: Label = %RescuedLabel
@onready var pause_button: TextureButton = %PauseButton


func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.coin_changed.connect(_on_coin_changed)
	GameState.rescued_changed.connect(_on_rescued_changed)
	GameState.pause_changed.connect(_on_pause_changed)
	pause_button.pressed.connect(_on_pause_pressed)

	_on_score_changed(GameState.score)
	_on_coin_changed(GameState.coin)
	_on_rescued_changed(GameState.rescued_count, GameState.rescued_target)
	_on_pause_changed(GameState.is_paused)


func _on_score_changed(score: int) -> void:
	score_label.text = "%s" % score


func _on_coin_changed(coin: int) -> void:
	coin_label.text = "%s" % coin


func _on_rescued_changed(count: int, target: int) -> void:
	rescued_label.text = "%d/%d" % [count, target]


func _on_pause_changed(is_paused: bool) -> void:
	visible = not is_paused


func _on_pause_pressed() -> void:
	GameState.set_paused(not GameState.is_paused)


func update_score(score: int) -> void:
	score_label.text = "%s" % score


func update_coin(coin: int) -> void:
	coin_label.text = "%s" % coin


func update_rescued(count: int, target: int) -> void:
	rescued_label.text = "%d/%d" % [count, target]
