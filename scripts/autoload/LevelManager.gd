extends Node

@export var level_scenes: Array[PackedScene] = []

var tutorial_completed: bool = false
var current_level_index: int = 0
var last_played_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## 主菜单开始新游戏时调用：根据教程完成状态决定起始关卡
func start_new_game() -> void:
	if not tutorial_completed:
		current_level_index = 0
	else:
		current_level_index = maxi(current_level_index, 1)


## 获取当前应加载的关卡场景
func get_current_level_packed() -> PackedScene:
	if level_scenes.is_empty():
		push_error("LevelManager: level_scenes 为空")
		return null
	var safe_index := clampi(current_level_index, 0, level_scenes.size() - 1)
	return level_scenes[safe_index]


## 关卡通关时调用：记录刚玩的关卡，推进 index，最后一关循环回非教程首关
func on_level_completed() -> void:
	last_played_index = current_level_index
	if current_level_index == 0:
		tutorial_completed = true
	var next_index := current_level_index + 1
	if next_index >= level_scenes.size():
		next_index = 1 if (tutorial_completed and level_scenes.size() > 1) else 0
	current_level_index = next_index


## 重试：回退到刚通关的关卡
func retry_last_played() -> void:
	current_level_index = last_played_index


## 判断刚通关的关卡之后是否还有下一关
func has_next_level() -> bool:
	return last_played_index < level_scenes.size() - 1
