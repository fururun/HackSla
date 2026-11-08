class_name Player
extends CharacterBody2D
## プレイヤー（T07）：8方向の移動、マウス方向への通常攻撃。
## 絵はドット絵ができるまでコードで描く仮のもの。向きは Facing の8方向で持つ。

signal attacked(skill: SkillDef, hits: int)
signal damaged(amount: float, source: Node)  ## 敵に殴られて、体力が減った（回避中は出ない。見た目用）

const MOVE_SPEED: float = 80.0
const AIM_DISTANCE: float = 100.0  ## 向いている方向の、狙う位置までの距離（向きだけが使われる）
const DODGE_SPEED: float = 230.0  ## 緊急回避の速さ
const DODGE_SECONDS: float = 0.18  ## 回避で動く時間（距離は約 41）
const DODGE_INVULN_SECONDS: float = 0.28  ## 回避のあいだ、攻撃を受けない時間（動きが終わったあとも少し残る）
const DODGE_COOLDOWN: float = 0.9  ## 次に回避できるまでの時間
const AUTO_AIM_RANGE: float = 80.0  ## この距離（地面の距離）以内に敵がいれば、その敵のほうを向いて攻撃する

var facing: int = 2  ## Facing の番号（最初は下向き）
var caster := SkillCaster.new()  ## スキル枠・チェイン・再使用時間を持つ（枠の付け替えは caster.loadout）
var vitals: PlayerVitals = PlayerVitals.new(caster.stats)  ## 体力・経験値（stats は caster と共有）
var _attack_t: float = -1.0  ## 攻撃の絵（5コマ）を出し始めてからの秒。負なら、出していない
var _swing_t: float = 0.0  ## 攻撃の振りの見た目（残り時間）
var autopilot: Autopilot  ## デバッグ用の自動戦闘（F2）。入っているあいだ、操作の代わりをする
var _dodge_left: float = 0.0  ## 回避で動いている残り時間
var _invuln_left: float = 0.0  ## 無敵の残り時間
var _dodge_cooldown_left: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO


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
	_invuln_left = maxf(0.0, _invuln_left - delta)
	_dodge_cooldown_left = maxf(0.0, _dodge_cooldown_left - delta)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var auto: bool = autopilot != null and autopilot.enabled
	if auto:
		input = autopilot.move_input(self, delta)
		if autopilot.wants_dodge(self):
			start_dodge(autopilot.dodge_direction)
	if Input.is_action_just_pressed("heal") or (auto and autopilot.wants_heal(self)):
		vitals.use_heal()
	if Input.is_action_just_pressed("dodge"):
		start_dodge(input)
	if _dodge_left > 0.0:
		_dodge_left -= delta
		velocity = _dodge_dir * DODGE_SPEED
		move_and_slide()
		queue_redraw()
		return
	velocity = input * MOVE_SPEED
	move_and_slide()
	if input != Vector2.ZERO and _swing_t <= 0.0:
		facing = Facing.dir8(input)

	if _swing_t > 0.0:
		_swing_t -= delta
	if _attack_t >= 0.0:
		_attack_t += delta
		if _attack_t >= ATTACK_FRAMES * ATTACK_FRAME_SECONDS:
			_attack_t = -1.0

	for slot: int in range(1, SkillLoadout.SLOT_COUNT + 1):
		if Input.is_action_pressed("skill_%d" % slot):
			use_skill(slot, aim_target())
	if auto and autopilot.wants_skill(self):
		var pick: int = autopilot.pick_skill_slot(self)  # 自動戦闘は、チェインを優先して、1回に1つだけ出す
		if pick > 0:
			use_skill(pick, aim_target())
	queue_redraw()


## スキルを出す向き：近くに敵がいれば、いちばん近い敵のほう。いなければ、キャラクターが向いている方向（8方向）。
## マウスの位置は使わない
func aim_target() -> Vector2:
	var enemy := nearest_enemy()
	if enemy != null:
		return enemy.global_position
	return global_position + Facing.to_vector(facing).normalized() * AIM_DISTANCE


## 自動で狙う範囲（AUTO_AIM_RANGE、地面の距離）にいる、いちばん近い敵。いなければ null
func nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := AUTO_AIM_RANGE
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e == null or not e.visible:
			continue
		var d := Iso.ground_distance(global_position, e.global_position)
		if d <= best_d:
			best = e
			best_d = d
	return best


## 敵に殴られた（EnemyManager.player_hit につなぐ）
func on_player_hit(damage: float, source: Node) -> void:
	if is_invulnerable() or vitals.is_dead():
		return
	vitals.take_damage(damage)
	damaged.emit(damage, source)


## 緊急回避：動いている向き（止まっているときは向いている向き）へ、すばやく動く。そのあいだは攻撃を受けない。出せたら true
func start_dodge(input: Vector2 = Vector2.ZERO) -> bool:
	if vitals.is_dead() or _dodge_cooldown_left > 0.0 or _dodge_left > 0.0:
		return false
	_dodge_dir = input.normalized() if input != Vector2.ZERO else Facing.to_vector(facing).normalized()
	facing = Facing.dir8(_dodge_dir)
	_dodge_left = DODGE_SECONDS
	_invuln_left = DODGE_INVULN_SECONDS
	_dodge_cooldown_left = DODGE_COOLDOWN
	return true


func is_invulnerable() -> bool:
	return _invuln_left > 0.0


func is_dodging() -> bool:
	return _dodge_left > 0.0


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
	play_attack_animation()
	attacked.emit(caster.last_skill, hits)
	return true


## 通常攻撃（スキル枠1）。互換のために残している
func try_basic_attack(target: Vector2) -> bool:
	return use_skill(1, target)


# ---- 絵（art/sprites/player/。作り方は make_player.py） ----
const SPRITE_DIR: String = "res://art/sprites/player/"
const SPRITE_SIZE: Vector2 = Vector2(30, 30)  ## 絵の大きさ（ドット数）。足元の中心が原点。高解像度の元は player_hi_*.png
const SPRITE_SCALE: float = 1.0  ## 絵の拡大率（絵はすでにゲームの大きさに縮めてある）
const WALK_FRAME_MS: int = 110  ## 歩きのモーションの1コマの長さ（ミリ秒）。4コマで1歩ずつ（右足・左足）
const LEG_ROWS: int = 6  ## 絵の下から、足として動かす行数
static var _textures: Dictionary = {}  ## 向き（front / back / side）-> Texture2D


const ATTACK_VIEWS: PackedStringArray = ["front", "side", "back", "diag_down", "diag_up"]  ## 攻撃の絵（5コマ）がある向き（8方向すべて。左右は反転）
const ATTACK_FRAMES: int = 5  ## 構え→振りかぶり→斬り下ろし→残心→構えに戻る
const ATTACK_FRAME_SECONDS: float = 0.07  ## 1コマの長さ。5コマで0.35秒
const ATTACK_FEET_ROW: float = 37.0  ## 攻撃の絵（48x40）の、足元の行
static var _attack_textures: Dictionary = {}  ## "向き_コマ" -> Texture2D


## 攻撃の絵のうち、出し始めて elapsed 秒のときのもの。絵がない向きは null
static func attack_texture(view: String, elapsed: float) -> Texture2D:
	if not ATTACK_VIEWS.has(view):
		return null
	var index: int = clampi(int(elapsed / ATTACK_FRAME_SECONDS), 0, ATTACK_FRAMES - 1)
	var key: String = "%s_%d" % [view, index]
	if not _attack_textures.has(key):
		_attack_textures[key] = load(SPRITE_DIR + "player_attack_%s_%d.png" % [view, index]) as Texture2D
	return _attack_textures[key]


## スキルを使った瞬間に、攻撃の絵の再生を始める（途中なら、最初から）
func play_attack_animation() -> void:
	_attack_t = 0.0


func is_attack_animating() -> bool:
	return _attack_t >= 0.0


const WALK_VIEWS: PackedStringArray = ["front", "side", "back", "diag_down", "diag_up"]  ## 歩きの絵（4コマ）がある向き（8方向すべて。左右は反転）
const WALK_FRAMES: int = 4  ## 歩きの絵のコマ数（0:足を前に出す 1:そろう 2:反対の足を前に出す 3:そろう）
static var _walk_textures: Dictionary = {}  ## "向き_コマ" -> Texture2D


## 歩いているときの、その時刻の絵（4コマの歩き）。斜めなど、歩きの絵がない向きは null
static func walk_texture(view: String, time_ms: int) -> Texture2D:
	if not WALK_VIEWS.has(view):
		return null
	var index: int = (time_ms / WALK_FRAME_MS) % WALK_FRAMES
	var key: String = "%s_%d" % [view, index]
	if not _walk_textures.has(key):
		_walk_textures[key] = load(SPRITE_DIR + "player_walk_%s_%d.png" % [view, index]) as Texture2D
	return _walk_textures[key]


static func _texture(view: String) -> Texture2D:
	if not _textures.has(view):
		_textures[view] = load(SPRITE_DIR + "player_%s.png" % view) as Texture2D
	return _textures[view]


## 向き（Facing の番号）から、使う絵と左右反転を決める。8方向：
## 下=前、上=後ろ、右=横（右向きの絵）、左=横の反転、斜めは斜めの絵。
## 斜めの絵（diag_down / diag_up）は、左向き（左下・左上）に描かれているので、右下・右上は反転して使う。
static func view_for(facing_index: int) -> Dictionary:
	match facing_index:
		0: return {"view": "side", "flip": false}       # 右
		1: return {"view": "diag_down", "flip": true}   # 右下
		2: return {"view": "front", "flip": false}      # 下
		3: return {"view": "diag_down", "flip": false}  # 左下
		4: return {"view": "side", "flip": true}        # 左
		5: return {"view": "diag_up", "flip": false}    # 左上
		6: return {"view": "back", "flip": false}       # 上
		_: return {"view": "diag_up", "flip": true}     # 7: 右上


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.35))  # 影
	var v := view_for(facing)
	var tex := _texture(v["view"])
	if tex == null:
		return
	var tint := Color(0.45, 0.4, 0.45) if vitals.is_dead() else Color.WHITE
	if is_invulnerable():
		tint = Color(0.7, 0.9, 1.0, 0.55)  # 回避中は、うすく青白く透ける
	var s := SPRITE_SCALE
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-s if v["flip"] else s, s))
	# 絵ごとに幅が違う（斜めは刀の分だけ広い）ので、絵の大きさから足元の中心を決める
	var size := tex.get_size()
	if _attack_t >= 0.0 and not vitals.is_dead():
		var attack_tex: Texture2D = attack_texture(v["view"], _attack_t)
		if attack_tex != null:
			# 攻撃の絵（斬撃の弧が入るので、立ち絵より広い）。足元の行を、足元に合わせる
			draw_texture(attack_tex, Vector2(-attack_tex.get_size().x * 0.5, -ATTACK_FEET_ROW), tint)
			return
	var moving: bool = velocity != Vector2.ZERO and not vitals.is_dead()
	var walk_tex: Texture2D = walk_texture(v["view"], Time.get_ticks_msec()) if moving else null
	if walk_tex != null:
		# 歩きの絵（4コマ）があるときは、その絵をそのまま出す（立ち絵の脚を動かす代わりに）
		draw_texture(walk_tex, Vector2(-walk_tex.get_size().x * 0.5, -walk_tex.get_size().y), tint)
		return
	var pose := walk_pose(moving, Time.get_ticks_msec())
	# 歩きのモーション：上半身は上下に弾み、足（下の LEG_ROWS 行を、左右に分けたもの）は交互に持ち上がる。
	# 上半身の絵は、足の1行ぶん下まで重ねて描き、弾んでもすき間が空かないようにする
	var upper_h := size.y - LEG_ROWS
	var half_w := floorf(size.x * 0.5)
	draw_texture_rect_region(tex, Rect2(-size.x * 0.5, -size.y + pose["bob"], size.x, upper_h + 1.0),
		Rect2(0, 0, size.x, upper_h + 1.0), tint)
	draw_texture_rect_region(tex, Rect2(-size.x * 0.5, -LEG_ROWS - pose["lift_left"], half_w, LEG_ROWS),
		Rect2(0, upper_h, half_w, LEG_ROWS), tint)
	draw_texture_rect_region(tex, Rect2(-size.x * 0.5 + half_w, -LEG_ROWS - pose["lift_right"], size.x - half_w, LEG_ROWS),
		Rect2(half_w, upper_h, size.x - half_w, LEG_ROWS), tint)


## 歩きのモーション（4コマ）。上半身の上下（bob）と、左足・右足を持ち上げるドット数。止まっているときは、すべて 0。
## 0:右足を上げる → 1:体が弾む → 2:左足を上げる → 3:体が弾む、の繰り返し
static func walk_pose(moving: bool, time_ms: int) -> Dictionary:
	if not moving:
		return {"bob": 0.0, "lift_left": 0.0, "lift_right": 0.0}
	match (time_ms / WALK_FRAME_MS) % 4:
		0: return {"bob": 0.0, "lift_left": 0.0, "lift_right": 1.0}
		1: return {"bob": -1.0, "lift_left": 0.0, "lift_right": 0.0}
		2: return {"bob": 0.0, "lift_left": 1.0, "lift_right": 0.0}
		_: return {"bob": -1.0, "lift_left": 0.0, "lift_right": 0.0}
