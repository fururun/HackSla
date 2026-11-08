class_name EnemyFx
extends Node2D
## 敵の攻撃の、使い捨ての小さなエフェクト。種類：
## RING（地面に広がる輪）、BURST（四方に飛ぶ火花）、FLASH（ぱっと光る玉）、CHARGE（ためる光が集まる）。
## 描くだけで、当たり判定は持たない。

enum Kind { RING, BURST, FLASH, CHARGE }

var kind: Kind = Kind.RING
var color: Color = Color.WHITE
var size: float = 20.0
var duration: float = 0.3
var _t: float = 0.0
var _seeds: Array[float] = []


static func spawn(parent: Node, kind_: Kind, pos: Vector2, color_: Color, size_: float, duration_: float = 0.3) -> EnemyFx:
	var fx := EnemyFx.new()
	fx.kind = kind_
	fx.color = color_
	fx.size = size_
	fx.duration = maxf(duration_, 0.05)
	fx.z_index = 2
	for i: int in 10:
		fx._seeds.append(randf())
	parent.add_child(fx)
	fx.global_position = pos
	return fx


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _ellipse(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 33:
		var a: float = TAU * float(i) / 32.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	return pts


func _draw() -> void:
	var k: float = clampf(_t / duration, 0.0, 1.0)
	var fade: float = 1.0 - k
	match kind:
		Kind.RING:
			# 地面を走る衝撃の輪（2重）。外へ広がりながら消える
			var r: float = size * (0.25 + 0.75 * sqrt(k))
			draw_polyline(_ellipse(r), Color(color.r, color.g, color.b, 0.9 * fade), 3.0)
			draw_polyline(_ellipse(r * 0.7), Color(1, 1, 1, 0.6 * fade), 1.5)
		Kind.BURST:
			# 四方へ飛ぶ火花
			var center: Vector2 = Vector2(0, -3)
			for i: int in 10:
				var angle: float = TAU * float(i) / 10.0 + _seeds[i] * 0.6
				var reach: float = size * (0.4 + 0.6 * _seeds[i]) * sqrt(k)
				var from: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.7) * reach * 0.6
				var to: Vector2 = center + Vector2(cos(angle), sin(angle) * 0.7) * reach
				draw_line(from, to, Color(color.r, color.g, color.b, fade), 2.0)
			draw_circle(center, size * 0.25 * fade, Color(1, 1, 1, 0.8 * fade))
		Kind.FLASH:
			var center2: Vector2 = Vector2(0, -4)
			draw_circle(center2, size * (0.5 + 0.5 * k), Color(color.r, color.g, color.b, 0.5 * fade))
			draw_circle(center2, size * 0.4 * fade, Color(1, 1, 1, 0.9 * fade))
		Kind.CHARGE:
			# 外から中心へ、光の粒が集まる（撃つ・叩きつける前のため）
			var center3: Vector2 = Vector2(0, -6)
			for i: int in 10:
				var angle2: float = TAU * float(i) / 10.0 + _seeds[i]
				var dist: float = size * (1.0 - k) * (0.6 + 0.4 * _seeds[i])
				draw_circle(center3 + Vector2(cos(angle2), sin(angle2) * 0.8) * dist, 1.4, Color(color.r, color.g, color.b, 0.4 + 0.6 * k))
			draw_circle(center3, size * 0.25 * k, Color(color.r, color.g, color.b, 0.7))
