class_name LineTelegraph
extends Node2D
## 突進の予告。敵の足元から進む先まで、細長い赤い帯が出て、根もとから満ちていく。満ちきった瞬間に突進が始まる。
## 帯は、地面の上の長方形（斜め視点でつぶれる）。使い捨て。

const BURST_SECONDS: float = 0.15

var _dir: Vector2 = Vector2.RIGHT  ## 地面での向き（単位。y は画面の2倍の尺度）
var _length: float = 80.0
var _half_width: float = 8.0
var _windup: float = 0.6
var _t: float = 0.0


func _init() -> void:
	z_index = 1


## dir は画面上の進む向き。length・width は地面のドット
func play(pos: Vector2, dir: Vector2, length: float, width: float, windup: float) -> void:
	global_position = pos
	_dir = Vector2(dir.x, dir.y * 2.0).normalized()
	_length = length
	_half_width = width * 0.5
	_windup = maxf(windup, 0.01)
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= _windup + BURST_SECONDS:
		queue_free()
		return
	queue_redraw()


func _quad(from_len: float, to_len: float) -> PackedVector2Array:
	var side: Vector2 = Vector2(-_dir.y, _dir.x) * _half_width
	var a: Vector2 = _dir * from_len
	var b: Vector2 = _dir * to_len
	var pts := PackedVector2Array([a - side, b - side, b + side, a + side])
	for i in pts.size():
		pts[i] = Vector2(pts[i].x, pts[i].y * 0.5)
	return pts


func _fill(pts: PackedVector2Array, color: Color) -> void:
	var colors := PackedColorArray()
	colors.resize(pts.size())
	colors.fill(color)
	draw_polygon(pts, colors)


func _draw() -> void:
	if _t < _windup:
		var k: float = _t / _windup
		_fill(_quad(0.0, _length), Color(0.9, 0.15, 0.15, 0.14))
		_fill(_quad(0.0, _length * k), Color(0.95, 0.2, 0.15, 0.30 + 0.25 * k))
		var edge: PackedVector2Array = _quad(0.0, _length)
		edge.append(edge[0])
		draw_polyline(edge, Color(1.0, 0.35, 0.3, 0.55 + 0.4 * k), 1.5)
	else:
		var f: float = 1.0 - (_t - _windup) / BURST_SECONDS
		_fill(_quad(0.0, _length), Color(1.0, 0.92, 0.85, 0.6 * f))
