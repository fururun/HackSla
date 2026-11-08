class_name FloatText
extends Label
## 世界の中に、一言を浮かべて、上へ流して、消す文字（「チェイン！ 砕氷」など）。使い捨て。

const RISE: float = 16.0
const LIFE: float = 0.9
const FONT_SIZE: int = 14

var _t: float = 0.0
var _start: Vector2


static func spawn(parent: Node, pos: Vector2, text_value: String, color: Color) -> FloatText:
	var label := FloatText.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	label.size = Vector2(160, 20)
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(label)
	label.global_position = pos - Vector2(label.size.x * 0.5, 0.0)
	label._start = label.position
	return label


func _process(delta: float) -> void:
	_t += delta
	position = _start + Vector2(0, -RISE * (_t / LIFE))
	modulate.a = clampf(1.6 * (1.0 - _t / LIFE), 0.0, 1.0)
	if _t >= LIFE:
		queue_free()
