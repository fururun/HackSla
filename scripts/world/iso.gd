class_name Iso
extends RefCounted
## 斜め見下ろし視点（アイソメトリック、横2:縦1）の計算をまとめたもの。
## 地面の円は画面では横長の楕円に見えるので、当たり判定の距離も縦を2倍にして測る。

const TILE_W: int = 32
const TILE_H: int = 16


## 地面上の距離（画面の縦方向を2倍にして測る）
static func ground_distance(a: Vector2, b: Vector2) -> float:
	var d := b - a
	return Vector2(d.x, d.y * 2.0).length()


## 地面上で半径 r の円の中にいるか
static func in_ground_circle(center: Vector2, point: Vector2, r: float) -> bool:
	return ground_distance(center, point) <= r


## 画面上の向きを、地面上の向きに直した角度差で扇形判定する
static func in_ground_arc(origin: Vector2, facing: Vector2, point: Vector2, r: float, half_angle_deg: float) -> bool:
	var d := point - origin
	var g := Vector2(d.x, d.y * 2.0)
	if g.length() > r:
		return false
	if g.length() < 0.001:
		return true
	var f := Vector2(facing.x, facing.y * 2.0).normalized()
	return absf(rad_to_deg(f.angle_to(g))) <= half_angle_deg
