extends Node2D

## 场景切换目标场景 - 验证切换后游戏恢复

func _ready() -> void:
	print("[TARGET] 目标场景已加载")
	print("[TARGET] 切换后 paused = ", get_tree().paused)
	# 等待过渡动画完成（exit 动画约 0.6s + 余量）
	await get_tree().create_timer(2.0, true).timeout
	print("[TARGET] 2秒后 paused = ", get_tree().paused)
	if not get_tree().paused:
		print("[TARGET] ✅ 游戏已恢复（paused=false）")
	else:
		print("[TARGET] ❌ 游戏仍暂停（paused=true）")

	if not SceneLoader._is_transitioning:
		print("[TARGET] ✅ SceneLoader._is_transitioning = false")
	else:
		print("[TARGET] ❌ SceneLoader._is_transitioning = true（过渡未完成）")

	print("[TARGET] === 场景切换测试结束 ===")
	get_tree().quit()
