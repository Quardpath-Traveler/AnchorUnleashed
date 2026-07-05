extends Node

@export var level_scenes: Array[PackedScene] = []

var tutorial_completed: bool = false
var current_level_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## 主菜单开始新游戏时调用：根据教程完成状态决定起始关卡
func start_new_game() -> void:
	current_level_index = 1 if tutorial_completed else 0


## 获取当前应加载的关卡场景
func get_current_level_packed() -> PackedScene:
	if level_scenes.is_empty():
		push_error("LevelManager: level_scenes 为空")
		return null
	var safe_index := clampi(current_level_index, 0, level_scenes.size() - 1)
	return level_scenes[safe_index]


## 关卡通关时调用：如果是教程则标记完成，不改 current_level_index（重试仍加载本关）
func on_level_completed() -> void:
	if current_level_index == 0:
		tutorial_completed = true
