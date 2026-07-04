extends CanvasLayer

const _FACE_PERFECT := preload("res://assets/art/UI/result_screen/still_can_anchor_face.png")
const _FACE_ALMOST := preload("res://assets/art/UI/result_screen/almost_there_face.png")
const _FACE_NOT_BAD := preload("res://assets/art/UI/result_screen/not_bad_face.png")
const _TITLE_PERFECT := preload("res://assets/art/UI/result_screen/still_can_anchor.png")
const _TITLE_ALMOST := preload("res://assets/art/UI/result_screen/almost_there.png")
const _TITLE_NOT_BAD := preload("res://assets/art/UI/result_screen/not_bad.png")

@onready var panel: TextureRect = %Panel
@onready var character_avatar: TextureRect = %CharacterAvatar
@onready var title_image: TextureRect = %TitleImage
@onready var score_label: Label = %ScoreLabel
@onready var coin_label: Label = %CoinLabel
@onready var rescued_label: Label = %RescuedLabel
@onready var rescue_info_label: Label = %RescueInfoLabel
@onready var retry_button: Button = %RetryButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	retry_button.pressed.connect(_on_retry_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	GameState.score_changed.connect(_on_score_changed)
	GameState.coin_changed.connect(_on_coin_changed)
	GameState.rescued_changed.connect(_on_rescued_changed)
	_on_score_changed(GameState.score)
	_on_coin_changed(GameState.coin)
	_on_rescued_changed(GameState.rescued_count, GameState.rescued_target)
	_play_panel_slide_in()


func _play_panel_slide_in() -> void:
	var original_left := panel.offset_left
	var original_right := panel.offset_right
	# 将 Panel 移到屏幕左侧之外（右边缘对齐屏幕左边缘 x=0）
	panel.offset_left = original_left - original_right
	panel.offset_right = 0.0
	# Tween 动画回到原位
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "offset_left", original_left, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "offset_right", original_right, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_score_changed(score: int) -> void:
	score_label.text = "%s" % score


func _on_coin_changed(coin: int) -> void:
	coin_label.text = "%s" % coin


func _on_rescued_changed(count: int, target: int) -> void:
	rescued_label.text = "%d/%d" % [count, target]
	rescue_info_label.text = "成功救援全场NPC (%d/%d)" % [count, target]
	_update_result_images(count, target)


func _update_result_images(count: int, target: int) -> void:
	if count == target:
		# 救起人数 == 目标人数 → 完美通关
		character_avatar.texture = _FACE_PERFECT
		title_image.texture = _TITLE_PERFECT
	elif count > 0 and target > 0:
		# 两者都非零（但不相等）→ 差一点
		character_avatar.texture = _FACE_ALMOST
		title_image.texture = _TITLE_ALMOST
	elif target > 0 and count == 0:
		# 目标非零但救起为 0 → 一个没救到
		character_avatar.texture = _FACE_NOT_BAD
		title_image.texture = _TITLE_NOT_BAD


func _on_retry_button_pressed() -> void:
	EventBus.scene_transition_requested.emit(GameState.current_level_scene)


func _on_main_menu_button_pressed() -> void:
	EventBus.scene_transition_requested.emit("res://scenes/main/Main.tscn")
