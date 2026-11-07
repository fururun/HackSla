class_name GroundDrop
extends Node2D
## 描画だけを担当し、更新と回収は LootDirector にまとめる。
var value: Variant
var age: float = 0.0
var tint: Color = Color.WHITE
var beam: bool = false

func activate(payload: Variant, at: Vector2) -> void:
	value = payload
	age = 0.0
	beam = payload is ItemInstance and payload.rarity.beam
	tint = payload.rarity.color if payload is ItemInstance else Color("66d9ee")
	if payload is int:
		tint = Color("ffd36a")
	global_position = at
	show()
	queue_redraw()

func deactivate() -> void:
	value = null
	beam = false
	hide()

func _draw() -> void:
	if value == null:
		return
	draw_ellipse_shadow()
	if beam:
		draw_line(Vector2(0, -3), Vector2(0, -45), Color(tint, 0.22), 7.0)
		draw_line(Vector2(0, -3), Vector2(0, -45), tint.lightened(0.4), 1.0)
	if value is GemInstance:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(4, -3), Vector2(0, 0), Vector2(-4, -3)]), tint)
	else:
		draw_rect(Rect2(-3, -5, 6, 4), tint)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
