extends Node2D

## 过渡动画测试 v3 - 完整场景切换流程

func _ready() -> void:
	print("[TEST] === 场景切换过渡测试 ===")
	print("[TEST] 调用 SceneLoader.change_scene() 切换到目标场景...")
	# 触发场景切换，SceneLoader 会播放过渡动画并切换场景
	SceneLoader.change_scene("res://debug/TransitionTarget.tscn")
	# 本场景将在切换时被销毁，后续验证由 TransitionTarget 完成
