class_name Enemy
extends Node2D
## 個体は状態と描画のみを持つ。移動・寿命の管理は EnemyManager に集約する。

const FLASH_DURATION: float = 0.08
const OUTLINE := Color("#171b26")
const SHADOW := Color(0, 0, 0, 0.35)
const EYE := Color("#fff0bd")
const PUPIL := Color("#272034")
const FANG := Color("#eee3c9")
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
var state: State = State.IDLE
var pack_id: int = -1
var attack_timer: float = 0.0

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
	var key: String = definition.behavior + definition.color.to_html() + str(is_flashing())
	if not _figures.has(key):
		_figures[key] = _make_figure(is_flashing())
	draw_set_transform(Vector2(_lean, 0))
	draw_mesh(_figures[key], null)
	draw_set_transform(Vector2.ZERO)


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
		var rim: Color = Color.WHITE if flash else SLIME_RIM
		var shine: Color = Color.WHITE if flash else SLIME_SHINE
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
