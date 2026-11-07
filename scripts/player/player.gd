class_name Player
extends CharacterBody2D
## プレイヤー（T07）：8方向の移動、マウス方向への通常攻撃。
## 絵はドット絵ができるまでコードで描く仮のもの。向きは Facing の8方向で持つ。

signal attacked(skill: SkillDef, hits: int)

const MOVE_SPEED: float = 80.0

var facing: int = 2  ## Facing の番号（最初は下向き）
var caster := SkillCaster.new()  ## スキル枠・チェイン・再使用時間を持つ（枠の付け替えは caster.loadout）
var vitals: PlayerVitals = PlayerVitals.new(caster.stats)  ## 体力・経験値（stats は caster と共有）
var _swing_t: float = 0.0  ## 攻撃の振りの見た目（残り時間）


func _ready() -> void:
	add_to_group("player")
	caster.name = "SkillCaster"
	add_child(caster)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	vitals.tick(delta)
	if vitals.is_dead():
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * MOVE_SPEED
	move_and_slide()
	if input != Vector2.ZERO and _swing_t <= 0.0:
		facing = Facing.dir8(input)

	if _swing_t > 0.0:
		_swing_t -= delta

	for slot: int in range(1, SkillLoadout.SLOT_COUNT + 1):
		if Input.is_action_pressed("skill_%d" % slot):
			use_skill(slot, get_global_mouse_position())
	queue_redraw()


## 敵に殴られた（EnemyManager.player_hit につなぐ）
func on_player_hit(damage: float, _source: Node) -> void:
	vitals.take_damage(damage)


## スキル枠 slot を狙った位置に向けて出す。出せたら true（空の枠・再使用時間中は false）
func use_skill(slot: int, target: Vector2) -> bool:
	if vitals.is_dead():
		return false
	caster.fx_parent = get_parent()
	var hits := caster.cast(slot, target, global_position, Facing.to_vector(facing))
	if hits < 0:
		return false
	var aim := target - global_position
	if aim.length() >= CombatConsts.MIN_AIM_DISTANCE:
		facing = Facing.dir8(aim)
	_swing_t = CombatConsts.SWING_TIME
	attacked.emit(caster.last_skill, hits)
	return true


## 通常攻撃（スキル枠1）。互換のために残している
func try_basic_attack(target: Vector2) -> bool:
	return use_skill(1, target)


# ---- 仮の絵 ----
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.35))  # 影
	draw_set_transform(Vector2.ZERO)
	var body := Color("#6b5a5a") if vitals.is_dead() else Color("#e8e2d0")
	draw_rect(Rect2(-3, -15, 6, 11), body)               # 体
	draw_circle(Vector2(0, -18), 3.0, Color("#f2d6b3"))  # 頭
	var f := Facing.to_vector(facing)
	var tip := Vector2(f.x * 9.0, f.y * 4.5 - 9.0)       # 向きの印（武器の代わり）
	draw_line(Vector2(0, -9), tip, Color("#ffd34d"), 2.0)
