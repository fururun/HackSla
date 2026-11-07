class_name AreaFx
extends Node2D
## 範囲スキル・爆発の仮エフェクト（地面の円がぱっと広がる）。SkillCaster がプールして使い回す。

var busy: bool = false
var _radius: float = 24.0
var _life: float = 0.3
var _t: float = 0.0
var _color: Color = Color.WHITE


func _init() -> void:
	z_index = 5
	hide()
	set_process(false)


func play(pos: Vector2, radius: float, color: Color, life: float) -> void:
	global_position = pos
	_radius = radius
	_color = color
	_life = maxf(life, 0.01)
	_t = 0.0
	busy = true
	show()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		busy = false
		hide()
		set_process(false)
		return
	queue_redraw()


func _draw() -> void:
	if not busy:
		return
	var k := _t / _life
	var r := _radius * (0.4 + 0.6 * minf(1.0, k * 2.0))
	var a := 1.0 - k
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))  # 地面の円 → 画面の楕円
	draw_circle(Vector2.ZERO, r, Color(_color.r, _color.g, _color.b, 0.3 * a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(_color.r, _color.g, _color.b, 0.9 * a), 1.0)
