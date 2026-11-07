class_name Enemy
extends Node2D
## 個体は状態と描画のみを持つ。移動・寿命の管理は EnemyManager に集約する。

var definition: EnemyDef
var life: float = 0.0
var hit_radius: float = 6.0
var active: bool = false
var manager: EnemyManager


func take_hit(amount: float, _skill: SkillDef) -> void:
	if not active or definition.is_immortal:
		return
	life = maxf(0.0, life - maxf(0.0, amount))
	if life <= 0.0:
		manager.despawn(self)


func _draw() -> void:
	if definition == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, hit_radius, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-4, -14, 8, 11), definition.color)
	draw_circle(Vector2(0, -17), 4.0, definition.color.lightened(0.15))
