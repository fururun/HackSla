class_name GroundRing
extends Node2D
## 範囲スキルの「届く範囲」を示す地面の輪。斜め視点（横2:縦1）で、地面の円が正しい楕円に見えるよう描く。
## 実際の当たり判定の半径ぴったりまで広がって止まり、そのあと消える。SkillCaster がプールして使い回す。

const POINTS: int = 48
const EXPAND_TIME: float = 0.16
const LIFE: float = 0.6
const GROUND_SQUASH: float = 0.5  ## 地面の円は、画面では縦が半分

var busy: bool = false
var _radius: float = 24.0
var _color: Color = Color.WHITE
var _t: float = 0.0


func _init() -> void:
	z_index = 1  # 床の上、キャラ・絵のエフェクトより下
	hide()
	set_process(false)


func play(pos: Vector2, radius: float, color: Color) -> void:
	global_position = pos
	reset_physics_interpolation()  # 使い回しの瞬間移動で、前の場所から滑ってこないように
	_radius = maxf(radius, 1.0)
	_color = color
	_t = 0.0
	busy = true
	show()
	set_process(true)
	queue_redraw()


func advance(delta: float) -> void:
	if not busy:
		return
	_t += delta
	if _t >= LIFE:
		busy = false
		hide()
		set_process(false)
		return
	queue_redraw()


func _process(delta: float) -> void:
	advance(delta)


## 今の半径（広がる間は 0 から実際の半径まで）
func current_radius() -> float:
	return _radius * clampf(_t / EXPAND_TIME, 0.0, 1.0)


func _draw() -> void:
	if not busy:
		return
	var r := current_radius()
	if r < 1.0:
		return
	var fade := 1.0 if _t < EXPAND_TIME else clampf(1.0 - (_t - EXPAND_TIME) / (LIFE - EXPAND_TIME), 0.0, 1.0)
	var pts := PackedVector2Array()
	for i in POINTS + 1:
		var a := TAU * float(i) / float(POINTS)
		pts.append(Vector2(cos(a) * r, sin(a) * r * GROUND_SQUASH))
	var fill := PackedColorArray()
	fill.resize(pts.size())
	fill.fill(Color(_color.r, _color.g, _color.b, 0.16 * fade))
	draw_polygon(pts, fill)
	draw_polyline(pts, Color(_color.r, _color.g, _color.b, 0.95 * fade), 2.0)
	# 内側にもう1本、細い輪（範囲の縁を強調する）
	var inner := PackedVector2Array()
	for p: Vector2 in pts:
		inner.append(p * 0.86)
	draw_polyline(inner, Color(1, 1, 1, 0.45 * fade), 1.0)
