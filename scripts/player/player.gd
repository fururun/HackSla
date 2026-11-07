class_name Player
extends CharacterBody2D
## プレイヤー（T07）：8方向の移動、マウス方向への通常攻撃。
## 絵はドット絵ができるまでコードで描く仮のもの。向きは Facing の8方向で持つ。

signal attacked(skill: SkillDef, hits: int)

const MOVE_SPEED: float = 80.0
const BASIC_SKILL_ID: String = "slash"

var facing: int = 2  ## Facing の番号（最初は下向き）
var _cooldowns: Dictionary = {}  ## skill id -> 残り秒
var _rng := RandomNumberGenerator.new()
var _swing_t: float = 0.0  ## 攻撃の振りの見た目（残り時間）


func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * MOVE_SPEED
	move_and_slide()
	if input != Vector2.ZERO and _swing_t <= 0.0:
		facing = Facing.dir8(input)

	for id: String in _cooldowns.keys():
		_cooldowns[id] = maxf(0.0, _cooldowns[id] - delta)
	if _swing_t > 0.0:
		_swing_t -= delta

	if Input.is_action_pressed("skill_1"):
		try_basic_attack(get_global_mouse_position())
	queue_redraw()


## 通常攻撃（スキル枠1）。狙った方向を向いて、扇形の範囲に当てる
func try_basic_attack(target: Vector2) -> bool:
	var skill: SkillDef = DataDB.skill(BASIC_SKILL_ID)
	if skill == null or _cooldowns.get(skill.id, 0.0) > 0.0:
		return false
	var dir := (target - global_position)
	if dir.length() < 1.0:
		dir = Facing.to_vector(facing)
	facing = Facing.dir8(dir)
	_cooldowns[skill.id] = skill.cooldown
	_swing_t = 0.12

	var hits := 0
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Node2D
		if enemy and Iso.in_ground_arc(global_position, dir, enemy.global_position, skill.range + skill.radius, 60.0):
			enemy.call("take_hit", skill.roll_damage(_rng), skill)
			hits += 1
	SlashFx.spawn(get_parent(), global_position, dir.normalized(), skill.range + skill.radius)
	attacked.emit(skill, hits)
	return true


# ---- 仮の絵 ----
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.35))  # 影
	draw_set_transform(Vector2.ZERO)
	var body := Color("#e8e2d0")
	draw_rect(Rect2(-3, -15, 6, 11), body)               # 体
	draw_circle(Vector2(0, -18), 3.0, Color("#f2d6b3"))  # 頭
	var f := Facing.to_vector(facing)
	var tip := Vector2(f.x * 9.0, f.y * 4.5 - 9.0)       # 向きの印（武器の代わり）
	draw_line(Vector2(0, -9), tip, Color("#ffd34d"), 2.0)
