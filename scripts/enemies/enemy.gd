class_name Enemy
extends Node2D
## 個体は状態と描画のみを持つ。移動・寿命の管理は EnemyManager に集約する。

const FLASH_DURATION: float = 0.08
const OUTLINE := Color("#171b26")
const SHADOW := Color(0, 0, 0, 0.35)
const EYE := Color("#fff0bd")
const PUPIL := Color("#272034")
const FANG := Color("#eee3c9")
const GOLEM_PATH: String = "res://art/sprites/enemies/rockgolem_front.png"
const GOLEM_SIZE: Vector2 = Vector2(30, 30)  ## 岩殻の絵の大きさ。足元の中心が原点
const GOLEM_FLASH := Color(3.0, 3.0, 3.0, 1.0)
const RAGE_TINT := Color(1.0, 0.42, 0.36, 1.0)  ## 激昂したボスは、さらに赤くなる
const TINT_BOOST: float = 1.6  ## 色違いの岩殻は、絵が暗くならないよう、色を明るめにかける
const WINDUP_TINT := Color(1.6, 0.55, 0.45, 1.0)  ## 攻撃の直前の、赤い光
const BOSS_TINT := Color(1.0, 0.72, 0.72, 1.0)  ## ボスは、岩殻の絵を赤みがかった色にして、ふつうの岩殻と見分ける
const DEFAULT_HIT_RADIUS: float = 6.0
const TANK_HIT_RADIUS: float = 10.0  ## 岩殻は大きいので、押し合いの半径も大きい
static var _golem: Texture2D
const ANIM_DIR: String = "res://art/sprites/enemies/"
const WALK_FRAME_MS: int = 140  ## 岩殻の歩きの1コマの長さ
const WALK_FRAMES: int = 4
const STRIKE_FRAME_MS: int = 90  ## 叩きつけたあとの、3コマ（叩きつけ・沈む・戻る）の1コマの長さ
const STRIKE_FRAMES: int = 3
const SLIME_MOVE_MS: int = 120  ## スライムの跳ねる動きの1コマの長さ
const SLIME_ATTACK_MS: int = 70  ## スライムの体当たりの1コマの長さ（4コマ）
const SPIT_RECOVER_MS: int = 110  ## 毒を吐いたあと（吐く・戻る）の1コマの長さ
static var _anim_sets: Dictionary = {}  ## 名前 -> Array[Texture2D]（コマの順）
const SLIME_RIM := Color("#9be860")  ## スライムの縁と目（明るい黄緑）
const SLIME_SHINE := Color("#c8f77a")  ## スライムのつや
const SLIME_UNDER := Color("#10304a")  ## スライムの下の影（紺）
const LIGHTEN: float = 0.22
const DARKEN: float = 0.28
const LEAN_PIXELS: float = 1.0
const LEAN_TRAVEL: float = 3.0

static var _figures: Dictionary[String, ArrayMesh] = {}

enum State { IDLE, CHASING, ATTACKING, WINDUP }

var ai_enabled: bool = false
var can_be_pushed: bool = true
var state: State = State.IDLE:
	set(value):
		if value != state:
			state = value
			if definition != null and definition.behavior == "tank":
				queue_redraw()  # 動き出したら、頭の上の体力の棒を出す
		else:
			state = value
var pack_id: int = -1
var attack_timer: float = 0.0
var aoe_timer: float = 0.0  ## 範囲攻撃までの待ち（秒）
var aoe_windup_left: float = 0.0  ## 範囲攻撃の予告のあいだ、残りの秒（0 なら予告していない）
var raged: bool = false  ## 激昂している（ボスの体力が半分以下）
var rain_timer: float = 0.0  ## 岩落としまでの待ち（秒）
var aoe_radius_now: float = 0.0  ## いまの範囲攻撃の半径（激昂中は広い）
var _strike_msec: int = -100000  ## 最後に叩きつけた（殴った・範囲攻撃・突進・弾）時刻
var _last_anim_texture: Texture2D  ## 前回描いた動きの絵（変わったときだけ描き直す）
var charge_phase: int = 0  ## 0:なし 1:予告中 2:突進中
var charge_timer: float = 0.0  ## 次の突進までの秒
var charge_left: float = 0.0  ## 予告または突進の、残りの秒
var charge_dir: Vector2 = Vector2.ZERO  ## 突進の向き（画面上の、1秒あたりの単位の向き）
var charge_hit: bool = false  ## この突進で、もう当てたか
var shot_timer: float = 0.0  ## 次に撃つまでの秒
var shot_windup_left: float = 0.0  ## 撃つ前のため。0 なら、ためていない
var rain_spots: Array = []  ## 予告中の岩落とし。{"pos": 地面の位置, "left": 残りの秒}

var definition: EnemyDef
var life: float = 0.0
var hit_radius: float = 6.0
var active: bool = false:
	set(value):
		active = value
		_flash_remaining = 0.0
		_lean = 0.0
		set_process(false)
		queue_redraw()
var manager: EnemyManager
var _flash_remaining: float = 0.0
var _lean: float = 0.0
var _last_position: Vector2 = Vector2.ZERO


func take_hit(amount: float, _skill: SkillDef) -> void:
	if not active or definition.is_immortal:
		return
	if not is_finite(amount) or amount <= 0.0 or life <= 0.0:
		return
	var damage: float = minf(life, amount)
	life -= damage
	_flash_remaining = FLASH_DURATION
	set_process(true)
	queue_redraw()
	manager.enemy_hit.emit(self, damage, life <= 0.0)
	if life <= 0.0:
		DeathDebris.spawn(manager, global_position)
		manager.play_death(self)
		manager.despawn(self)


func _ready() -> void:
	_last_position = position
	set_notify_local_transform(true)
	set_process(_flash_remaining > 0.0)


## 移動の向きが反転したときだけ絵を更新する。待機個体の毎フレーム処理はない。
func _notification(what: int) -> void:
	if what != NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		return
	var movement: Vector2 = position - _last_position
	if not active or state != State.CHASING:
		_last_position = position
		return
	if absf(movement.x) < LEAN_TRAVEL:
		return
	_last_position = position
	var lean: float = signf(movement.x) * LEAN_PIXELS
	if lean != _lean:
		_lean = lean
		queue_redraw()


func is_flashing() -> bool:
	return _flash_remaining > 0.0


func tick_flash(delta: float) -> void:
	if not is_flashing():
		return
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	if not is_flashing():
		set_process(false)
		queue_redraw()


func _process(delta: float) -> void:
	tick_flash(delta)


func _draw() -> void:
	if definition == null:
		return
	draw_rect(Rect2(-hit_radius, -2, hit_radius * 2, 4), SHADOW)
	if definition.behavior == "tank":
		# 岩殻はドット絵（AI が描いたもの）。被弾の点滅は明るく飛ばす
		var tex := golem_anim_texture()
		if tex == null:
			tex = _golem_texture()
		if tex != null:
			var tint: Color = Color.WHITE
			if is_flashing():
				tint = GOLEM_FLASH
			elif state == State.WINDUP or charge_phase == 1:
				tint = WINDUP_TINT  # 殴る・突進の直前は、赤く光る（見てから避けられる）
			elif definition.is_boss:
				tint = RAGE_TINT if raged else BOSS_TINT
			elif definition.tint != Color.WHITE:
				tint = Color(definition.tint.r * TINT_BOOST, definition.tint.g * TINT_BOOST, definition.tint.b * TINT_BOOST, 1.0)  # 色違いは、明るく染める
			var s: float = definition.scale  # ボスは大きく描く（足元の中心が原点のまま）
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
			draw_texture(tex, Vector2(-tex.get_size().x * 0.5, -tex.get_size().y), tint)
			draw_set_transform(Vector2.ZERO)
		_draw_life_bar()
		return
	var anim: Texture2D = current_anim_texture()
	if anim != null:
		# スライムの動きの絵（ChatGPT製）。被弾の点滅は、明るく飛ばす。絵の下の端は、足元の影の下の端（y=1）
		draw_texture(anim, Vector2(-anim.get_size().x * 0.5, 1.0 - anim.get_size().y), GOLEM_FLASH if is_flashing() else Color.WHITE)
		return
	var key: String = definition.behavior + definition.color.to_html() + str(is_flashing())
	if not _figures.has(key):
		_figures[key] = _make_figure(is_flashing())
	draw_set_transform(Vector2(_lean, 0))
	draw_mesh(_figures[key], null)
	draw_set_transform(Vector2.ZERO)


## 頭の上の体力の棒（ボス・中ボス＝岩殻）。動き出したか、傷ついたら出す
func life_bar_visible() -> bool:
	return active and definition != null and definition.behavior == "tank" \
		and (state != State.IDLE or life < definition.life)


func life_ratio() -> float:
	return clampf(life / maxf(definition.life, 1.0), 0.0, 1.0)


func _draw_life_bar() -> void:
	if not life_bar_visible():
		return
	var s: float = definition.scale
	var w: float = 24.0 * s if definition.is_boss else 24.0
	var top: float = -GOLEM_SIZE.y * s - 6.0
	var fill_color: Color = Color("#ff4a3a") if raged else Color("#d9382f")
	draw_rect(Rect2(-w * 0.5 - 1, top - 1, w + 2, 5), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(-w * 0.5, top, w, 3), Color("#3a1414"))
	draw_rect(Rect2(-w * 0.5, top, w * life_ratio(), 3), fill_color)


## 動きの絵（名前_0.png, 名前_1.png ...）のうち index コマ目。絵がなければ null
static func anim_texture(anim_name: String, index: int) -> Texture2D:
	if not _anim_sets.has(anim_name):
		var frames: Array[Texture2D] = []
		for i: int in 8:
			var path: String = ANIM_DIR + "%s_%d.png" % [anim_name, i]
			if not ResourceLoader.exists(path):
				break
			frames.append(load(path) as Texture2D)
		_anim_sets[anim_name] = frames
	var set: Array = _anim_sets[anim_name]
	if index < 0 or index >= set.size():
		return null
	return set[index]


## 叩きつけ・殴り・範囲攻撃・突進・弾の、「振り下ろした瞬間」を知らせる（岩殻の絵が、叩きつけの動きになる）
func play_strike() -> void:
	_strike_msec = Time.get_ticks_msec()
	queue_redraw()


## 攻撃の予告・ためのあいだ（岩殻は腕を振り上げた絵になる）
func is_winding_up() -> bool:
	return state == State.WINDUP or aoe_windup_left > 0.0 or charge_phase == 1


## いまの動きの絵（岩殻・スライム・毒吐きスライム）。なければ null（岩殻は立ち絵、スライムは、コードで描いた絵）
func current_anim_texture() -> Texture2D:
	if definition == null:
		return null
	match definition.behavior:
		"tank":
			return golem_anim_texture()
		"melee_swarm":
			return _slime_anim_texture()
		"ranged":
			return _spitter_anim_texture()
	return null


## スライム：体当たりのあと（4コマ）／動いているとき（跳ねる4コマ）／待機（跳ねる動きの最初のコマ）
func _slime_anim_texture() -> Texture2D:
	var now: int = Time.get_ticks_msec()
	var since: int = now - _strike_msec
	if since >= 0 and since < SLIME_ATTACK_MS * 4:
		return anim_texture("slime_attack", since / SLIME_ATTACK_MS)
	if state == State.CHASING:
		var phase: int = int(get_instance_id() % 1000)
		return anim_texture("slime_move", ((now + phase) / SLIME_MOVE_MS) % 4)
	return anim_texture("slime_move", 0)


## 毒吐きスライム：吐いたあと（吐く→戻る）／吐く前のため（縮む→膨らむ）／動いているとき／待機
func _spitter_anim_texture() -> Texture2D:
	var now: int = Time.get_ticks_msec()
	var since: int = now - _strike_msec
	if since >= 0 and since < SPIT_RECOVER_MS * 2:
		return anim_texture("spitter_attack", 2 + since / SPIT_RECOVER_MS)
	if shot_windup_left > 0.0:
		var half: bool = shot_windup_left > definition.shot_windup * 0.5
		return anim_texture("spitter_attack", 0 if half else 1)
	if state == State.CHASING:
		var phase: int = int(get_instance_id() % 1000)
		return anim_texture("spitter_move", ((now + phase) / SLIME_MOVE_MS) % 4)
	return anim_texture("spitter_move", 0)


## 岩殻の、いまの動きの絵：叩きつけたあと（叩きつけ→沈む→戻る）、予告中（腕を振り上げる）、歩いているとき（4コマ）。
## どれでもなければ null（立ち絵）
func golem_anim_texture() -> Texture2D:
	var now: int = Time.get_ticks_msec()
	var since: int = now - _strike_msec
	if since >= 0 and since < STRIKE_FRAME_MS * STRIKE_FRAMES:
		return anim_texture("rockgolem_attack", 2 + since / STRIKE_FRAME_MS)
	if is_winding_up():
		return anim_texture("rockgolem_attack", 1)
	if state == State.CHASING:
		var phase: int = int(get_instance_id() % 1000)  # 個体ごとに、歩きの位相をずらす
		return anim_texture("rockgolem_walk", ((now + phase) / WALK_FRAME_MS) % WALK_FRAMES)
	return null


## 動きの絵が変わったときだけ、描き直す（EnemyManager が、岩殻だけに毎フレーム呼ぶ）
func update_anim() -> void:
	var tex: Texture2D = current_anim_texture()
	if tex != _last_anim_texture:
		_last_anim_texture = tex
		queue_redraw()


static func _golem_texture() -> Texture2D:
	if _golem == null:
		_golem = load(GOLEM_PATH) as Texture2D
	return _golem


func _make_figure(flash: bool) -> ArrayMesh:
	var figure := PixelFigure.new()
	var base: Color = Color.WHITE if flash else definition.color
	var dark: Color = Color.WHITE if flash else base.darkened(DARKEN)
	var light: Color = Color.WHITE if flash else base.lightened(LIGHTEN)
	var edge: Color = Color.WHITE if flash else OUTLINE
	if definition.behavior == "tank":
		# 重い岩殻。横幅と肩の段差でスライムと区別する。
		figure.add_rect(Rect2(-8, -20, 16, 17), edge)
		figure.add_rect(Rect2(-11, -17, 22, 10), edge)
		figure.add_rect(Rect2(-7, -19, 14, 7), light)
		figure.add_rect(Rect2(-10, -16, 5, 8), dark)
		figure.add_rect(Rect2(5, -16, 5, 8), base)
		figure.add_rect(Rect2(-6, -11, 12, 7), base)
		figure.add_rect(Rect2(1, -10, 5, 6), dark)
		figure.add_rect(Rect2(-5, -3, 4, 3), edge)
		figure.add_rect(Rect2(2, -3, 4, 3), edge)
		figure.add_rect(Rect2(-4, -15, 8, 3), edge)
		figure.add_rect(Rect2(-3, -14, 2, 1), Color.WHITE if flash else EYE)
		figure.add_rect(Rect2(2, -14, 2, 1), Color.WHITE if flash else EYE)
	else:
		# スライム：横に広い平たい半球。明るい黄緑の縁、濃い緑の本体、上のつや、内向きにつり上がった目、下に紺の影。
		# 段を付けた輪郭を、1行ずつの整数の矩形（y, 半幅）で重ねる。
		var custom: bool = definition.behavior == "ranged"  # 遠くから撃つスライムは、色を変える（縁とつやも、本体の色から作る）
		var rim: Color = Color.WHITE if flash else (base.lightened(0.5) if custom else SLIME_RIM)
		var shine: Color = Color.WHITE if flash else (base.lightened(0.7) if custom else SLIME_SHINE)
		var body: Color = Color.WHITE if flash else base
		var under: Color = Color.WHITE if flash else SLIME_UNDER
		for row: Array in [[-8, 2], [-7, 4], [-6, 5], [-5, 6], [-4, 6], [-3, 6], [-2, 5]]:
			figure.add_rect(Rect2(-row[1], row[0], row[1] * 2, 1), rim)
		for row: Array in [[-1, 4], [0, 2]]:
			figure.add_rect(Rect2(-row[1], row[0], row[1] * 2, 1), under)
		for row: Array in [[-7, 2], [-6, 3], [-5, 4], [-4, 4], [-3, 4], [-2, 3]]:
			figure.add_rect(Rect2(-row[1], row[0], row[1] * 2, 1), body)
		figure.add_rect(Rect2(-3, -6, 2, 1), shine)
		figure.add_rect(Rect2(-4, -5, 1, 1), shine)
		figure.add_rect(Rect2(1, -6, 1, 1), shine)
		figure.add_rect(Rect2(-3, -4, 1, 1), rim)  # 目（内向きにつり上がる）
		figure.add_rect(Rect2(-2, -3, 1, 1), rim)
		figure.add_rect(Rect2(2, -4, 1, 1), rim)
		figure.add_rect(Rect2(1, -3, 1, 1), rim)
	return figure.make_mesh()
