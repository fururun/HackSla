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


# ---- 絵（art/sprites/player/。作り方は make_player.py） ----
const SPRITE_DIR: String = "res://art/sprites/player/"
const SPRITE_SIZE: Vector2 = Vector2(30, 30)  ## 絵の大きさ（ドット数）。足元の中心が原点。高解像度の元は player_hi_*.png
const SPRITE_SCALE: float = 1.0  ## 絵の拡大率（絵はすでにゲームの大きさに縮めてある）
const BOB_INTERVAL_MS: int = 140  ## 歩いているときの上下の揺れの間隔
static var _textures: Dictionary = {}  ## 向き（front / back / side）-> Texture2D


static func _texture(view: String) -> Texture2D:
	if not _textures.has(view):
		_textures[view] = load(SPRITE_DIR + "player_%s.png" % view) as Texture2D
	return _textures[view]


## 向き（Facing の番号）から、使う絵と左右反転を決める。下向き=前、上向き=後ろ、横=横（左向きは反転）
static func view_for(facing_index: int) -> Dictionary:
	match facing_index:
		0: return {"view": "side", "flip": false}
		1: return {"view": "front", "flip": false}
		2: return {"view": "front", "flip": false}
		3: return {"view": "front", "flip": true}
		4: return {"view": "side", "flip": true}
		5: return {"view": "back", "flip": true}
		6: return {"view": "back", "flip": false}
		_: return {"view": "back", "flip": false}  # 7: 右上


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.35))  # 影
	var v := view_for(facing)
	var tex := _texture(v["view"])
	if tex == null:
		return
	var bob := 0.0
	if velocity != Vector2.ZERO and (Time.get_ticks_msec() / BOB_INTERVAL_MS) % 2 == 1:
		bob = -1.0  # 歩いているとき、1ドットだけ上下に揺れる
	var tint := Color(0.45, 0.4, 0.45) if vitals.is_dead() else Color.WHITE
	var s := SPRITE_SCALE
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2(-s if v["flip"] else s, s))
	draw_texture(tex, Vector2(-SPRITE_SIZE.x * 0.5, -SPRITE_SIZE.y), tint)
