extends Node2D

@onready var level_container := $世界/关卡容器
@onready var player: Boat = $玩家
@onready var pause_menu := $暂停菜单

var current_level: Node2D = null


func _ready() -> void:
	GameState.reset()
	_instantiate_level()
	_sync_crew_tracking()
	GameState.pause_changed.connect(_on_pause_changed)
	_on_pause_changed(GameState.is_paused)


func _instantiate_level() -> void:
	var level_packed := LevelManager.get_current_level_packed()
	if level_packed == null:
		return
	current_level = level_packed.instantiate()
	level_container.add_child(current_level)
	if current_level.has_method("setup"):
		current_level.setup(player)
	if current_level.has_method("get_start_position"):
		player.global_position = current_level.get_start_position()
	if current_level.has_signal("level_completed"):
		current_level.level_completed.connect(_on_level_completed)


func _sync_crew_tracking() -> void:
	if current_level == null:
		return
	var npc_count: int = current_level.find_children("*", "FloatingNPC").size()
	var initial_crew: int = player.crew_count
	GameState.set_rescued_count(initial_crew)
	GameState.set_rescued_target(npc_count + initial_crew)


func _on_level_completed() -> void:
	LevelManager.on_level_completed()
	EventBus.game_completed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameState.set_paused(not GameState.is_paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_reset"):
		get_viewport().set_input_as_handled()
		_reset_current_scene()


func _reset_current_scene() -> void:
	SceneLoader.reload_scene()


func _on_pause_changed(is_paused: bool) -> void:
	pause_menu.visible = is_paused
