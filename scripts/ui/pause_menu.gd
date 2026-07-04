extends CanvasLayer

signal resume_requested

@onready var score_label: Label = %ScoreLabel
@onready var coin_label: Label = %CoinLabel
@onready var rescued_label: Label = %RescuedLabel
@onready var sound_slider: HSlider = %SoundSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var resume_button: Button = %ResumeButton
@onready var continue_button: Button = %ContinueButton
@onready var restart_button: Button = %RestartButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	GameState.score_changed.connect(_on_score_changed)
	GameState.coin_changed.connect(_on_coin_changed)
	GameState.rescued_changed.connect(_on_rescued_changed)
	GameState.pause_changed.connect(_on_pause_changed)

	resume_button.pressed.connect(_on_resume_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)

	sound_slider.value_changed.connect(_on_sound_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)

	sound_slider.value = _get_bus_volume("SFX")
	music_slider.value = _get_bus_volume("Music")

	_on_score_changed(GameState.score)
	_on_coin_changed(GameState.coin)
	_on_rescued_changed(GameState.rescued_count, GameState.rescued_target)
	_on_pause_changed(GameState.is_paused)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		GameState.set_paused(false)
		get_viewport().set_input_as_handled()


func _on_pause_changed(is_paused: bool) -> void:
	visible = is_paused


func _on_score_changed(score: int) -> void:
	score_label.text = "%s" % score


func _on_coin_changed(coin: int) -> void:
	coin_label.text = "%s" % coin


func _on_rescued_changed(count: int, target: int) -> void:
	rescued_label.text = "%d/%d" % [count, target]


func _on_resume_button_pressed() -> void:
	GameState.set_paused(false)
	resume_requested.emit()


func _on_continue_button_pressed() -> void:
	GameState.set_paused(false)
	resume_requested.emit()


func _on_restart_button_pressed() -> void:
	GameState.set_paused(false)
	SceneLoader.reload_scene()


func _on_main_menu_button_pressed() -> void:
	GameState.set_paused(false)
	EventBus.scene_transition_requested.emit("res://scenes/main/Main.tscn")


func _on_sound_slider_changed(value: float) -> void:
	_set_bus_volume("SFX", value)


func _on_music_slider_changed(value: float) -> void:
	_set_bus_volume("Music", value)


func _get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = AudioServer.get_bus_index("Master")
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = AudioServer.get_bus_index("Master")
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
