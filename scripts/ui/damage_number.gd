class_name DamageNumber
extends Label
## ダメージの数字（浮かんで消える）。大量に出る場合は T18 で使い回し（プール化）に変える。

const LIFE: float = 0.6

var _t: float = 0.0
var _start: Vector2


static func spawn(parent: Node, pos: Vector2, amount: float) -> DamageNumber:
	var n := DamageNumber.new()
	n.text = str(roundi(amount))
	n.add_theme_font_size_override("font_size", 8)
	n.add_theme_color_override("font_color", Color.WHITE)
	n.add_theme_constant_override("outline_size", 2)
	n.add_theme_color_override("font_outline_color", Color.BLACK)
	n.size = Vector2(24, 10)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.z_index = 20
	n._start = pos + Vector2(randf_range(-6, 6) - 12, 0)
	n.position = n._start
	parent.add_child(n)
	return n


func _process(delta: float) -> void:
	_t += delta
	position = _start + Vector2(0, -14.0 * (_t / LIFE))
	modulate.a = clampf(1.5 - _t / LIFE * 1.5, 0.0, 1.0)
	if _t >= LIFE:
		queue_free()
