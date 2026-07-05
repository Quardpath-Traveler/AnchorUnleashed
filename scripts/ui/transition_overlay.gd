extends CanvasLayer


signal enter_complete
signal exit_complete


@export var enter_duration: float = 0.6
@export var exit_duration: float = 0.6

@onready var wipe_image: TextureRect = $WipeImage


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_setup_size()
	visible = false


func _setup_size() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	wipe_image.size = viewport_size


func play_enter() -> void:
	_setup_size()
	var viewport_size := get_viewport().get_visible_rect().size
	wipe_image.position = Vector2(-viewport_size.x, 0.0)
	visible = true
	AudioManager.play_transition()

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(wipe_image, "position:x", 0.0, enter_duration)
	tween.tween_callback(func() -> void: enter_complete.emit())


func play_exit() -> void:
	_setup_size()
	var viewport_size := get_viewport().get_visible_rect().size
	wipe_image.position = Vector2(0.0, 0.0)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(wipe_image, "position:x", viewport_size.x, exit_duration)
	tween.tween_callback(func() -> void:
		visible = false
		exit_complete.emit()
	)
