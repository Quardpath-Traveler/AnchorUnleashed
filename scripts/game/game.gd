extends Node2D

@onready var level := $世界/关卡
@onready var player := $玩家
@onready var pause_menu := $暂停菜单


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset()
	GameState.pause_changed.connect(_on_pause_changed)
	if level.has_method("setup"):
		level.setup(player)
	if level.has_method("get_start_position"):
		player.global_position = level.get_start_position()
	_on_pause_changed(GameState.is_paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameState.set_paused(not GameState.is_paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_reset"):
		get_viewport().set_input_as_handled()
		_reset_current_scene()


func _reset_current_scene() -> void:
	Engine.time_scale = 1.0
	GameState.set_paused(false)
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("Failed to reload current scene: %s" % error)


func _on_pause_changed(is_paused: bool) -> void:
	pause_menu.visible = is_paused
