class_name DebugGraph
extends Control

@export var sample_count: int = 180
@export var line_color_positive: Color = Color(0.2, 0.9, 0.3)
@export var line_color_negative: Color = Color(0.9, 0.3, 0.2)
@export var zero_line_color: Color = Color(0.5, 0.5, 0.5, 0.5)
@export var max_value: float = 12.0

var _samples: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	_samples.resize(sample_count)
	_samples.fill(0.0)

func push_sample(value: float) -> void:
	for i in range(_samples.size() - 1):
		_samples[i] = _samples[i + 1]
	_samples[_samples.size() - 1] = value
	queue_redraw()

func _draw() -> void:
	var rect := get_rect()
	var mid_y: float = rect.size.y * 0.5
	draw_line(Vector2(0.0, mid_y), Vector2(rect.size.x, mid_y), zero_line_color, 1.0, true)

	var step_x: float = rect.size.x / float(_samples.size() - 1)
	for i in range(_samples.size() - 1):
		var y1 := _value_to_y(_samples[i], rect.size.y)
		var y2 := _value_to_y(_samples[i + 1], rect.size.y)
		var color := line_color_positive if _samples[i] >= 0.0 else line_color_negative
		draw_line(Vector2(i * step_x, y1), Vector2((i + 1) * step_x, y2), color, 2.0)

func _value_to_y(value: float, height: float) -> float:
	var ratio := clampf(value / max_value, -1.0, 1.0)
	return height * 0.5 - ratio * height * 0.45
