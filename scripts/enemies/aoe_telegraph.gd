class_name AoeTelegraph
extends Node2D
## 範囲攻撃の予告。足元に、赤い円（斜め視点の楕円）が出て、中から外へ満ちていく。満ちきった瞬間が攻撃で、
## 白く光って消える。円の外にいれば当たらない（プレイヤーはそれまでに外へ出る）。
## 使い捨て（ボスの範囲攻撃は数秒に1回なので、プールは使わない）。

const POINTS: int = 40
const GROUND_SQUASH: float = 0.5
const BURST_SECONDS: float = 0.25

var _radius: float = 40.0
var _windup: float = 1.0
var _t: float = 0.0


func _init() -> void:
	z_index = 1  # 床の上、キャラより下


func play(pos: Vector2, radius: float, windup: float) -> void:
	global_position = pos
	_radius = maxf(radius, 1.0)
	_windup = maxf(windup, 0.01)
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= _windup + BURST_SECONDS:
		queue_free()
		return
	queue_redraw()


func _ellipse(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in POINTS + 1:
		var a := TAU * float(i) / float(POINTS)
		pts.append(Vector2(cos(a) * r, sin(a) * r * GROUND_SQUASH))
	return pts


func _fill(pts: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray()
	colors.resize(pts.size())
	colors.fill(color)
	draw_polygon(pts, colors)


func _draw() -> void:
	if _t < _windup:
		var k := _t / _windup
		_fill(_ellipse(_radius), Color(0.9, 0.15, 0.15, 0.14))                 # 範囲いっぱいの、うすい赤
		_fill(_ellipse(_radius * k), Color(0.95, 0.2, 0.15, 0.30 + 0.25 * k))  # 中から満ちていく
		draw_polyline(_ellipse(_radius), Color(1.0, 0.35, 0.3, 0.55 + 0.4 * k), 2.0)
	else:
		var f := 1.0 - (_t - _windup) / BURST_SECONDS  # 満ちきったあと、白く光って消える
		_fill(_ellipse(_radius), Color(1.0, 0.92, 0.85, 0.7 * f))
		draw_polyline(_ellipse(_radius), Color(1.0, 1.0, 1.0, f), 3.0)
