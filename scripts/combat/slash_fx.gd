class_name SlashFx
extends Node2D
## 斬撃の仮エフェクト（地面に沿った扇形を一瞬だけ描く）。
## pixelfx などで作ったスプライトシートができたら差し替える（T18）。

const LIFE: float = 0.12

var _dir: Vector2 = Vector2.RIGHT
var _reach: float = 30.0
var _t: float = 0.0


static func spawn(parent: Node, pos: Vector2, dir: Vector2, reach: float) -> SlashFx:
	var fx := SlashFx.new()
	fx._dir = dir
	fx._reach = reach
	fx.position = pos
	fx.z_index = 5
	parent.add_child(fx)
	return fx


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / LIFE
	var g := Vector2(_dir.x, _dir.y * 2.0).normalized()  # 地面上の向き
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 13:
		var ang := g.angle() + deg_to_rad(-60.0 + 10.0 * i)
		var p := Vector2.RIGHT.rotated(ang) * _reach
		pts.append(Vector2(p.x, p.y * 0.5))  # 地面の円 → 画面の楕円
	draw_colored_polygon(pts, Color(1.0, 0.95, 0.75, 0.35 * a))
	draw_polyline(pts.slice(1), Color(1, 1, 1, 0.9 * a), 1.0)
