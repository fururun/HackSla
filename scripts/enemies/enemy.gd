class_name Enemy
extends Node2D
## 個体は状態と描画のみを持つ。移動・寿命の管理は EnemyManager に集約する。

enum State { IDLE, CHASING, ATTACKING, WINDUP }

var ai_enabled: bool = false
var can_be_pushed: bool = true
var state: State = State.IDLE
var pack_id: int = -1
var attack_timer: float = 0.0

var definition: EnemyDef
var life: float = 0.0
var hit_radius: float = 6.0
var active: bool = false
var manager: EnemyManager


func take_hit(amount: float, _skill: SkillDef) -> void:
	if not active or definition.is_immortal:
		return
	if not is_finite(amount) or amount <= 0.0 or life <= 0.0:
		return
	var damage: float = minf(life, amount)
	life -= damage
	manager.enemy_hit.emit(self, damage, life <= 0.0)
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
