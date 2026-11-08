class_name EnemyBullet
extends Node2D
## 敵の弾の絵。光る玉と、うしろに伸びる尾。動きと当たり判定は EnemyManager がまとめて持つ（1つずつ処理を持たない）。

var direction: Vector2 = Vector2.RIGHT  ## 画面上の進む向き（単位）
var color: Color = Color(0.7, 0.45, 1.0)
var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var pulse: float = 1.0 + 0.15 * sin(_age * 30.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2(0, 10), 3.0, Color(0, 0, 0, 0.3))  # 地面の影
	draw_set_transform(Vector2.ZERO)
	var center: Vector2 = Vector2(0, -5)
	for i: int in range(4, 0, -1):  # 尾
		var back: Vector2 = center - direction * float(i) * 3.0
		draw_circle(back, 3.2 - float(i) * 0.6, Color(color.r, color.g, color.b, 0.16 * (5 - i)))
	draw_circle(center, 5.5 * pulse, Color(color.r, color.g, color.b, 0.28))  # 外側のにじみ
	draw_circle(center, 3.4 * pulse, color)
	draw_circle(center, 1.6, Color(1, 1, 1, 0.95))  # 芯
