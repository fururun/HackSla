class_name TrainingDummy
extends Node2D
## 案山子：倒れない練習用の的。ダメージの数字と、直近5秒の平均ダメージ（DPS）を出す。
## スキル・補助ジェム・チェインを試す場所として、拠点にも置く予定。

const DPS_WINDOW: float = 5.0
const FLASH_DURATION: float = 0.08
const OUTLINE := Color("#302a29")
const WOOD := Color("#94704b")
const STRAW := Color("#c5ac71")
const STRAW_SHADE := Color("#8e744e")
const STRAW_LIGHT := Color("#e2cb8e")
const SHADOW := Color(0, 0, 0, 0.35)

signal damaged(amount: float)  ## 殴られた（画面のDPSの集計用）

var hit_radius: float = 6.0
var _hits: Array = []  ## [時刻, ダメージ]
var _flash: float = 0.0
var _label: Label


func _ready() -> void:
	add_to_group("enemies")
	_label = Label.new()
	_label.position = Vector2(-24, -40)
	_label.size = Vector2(48, 10)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color("#ffd34d"))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_label)


func take_hit(amount: float, _skill: SkillDef) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_hits.append([now, amount])
	_flash = FLASH_DURATION
	queue_redraw()
	damaged.emit(amount)
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -26), amount)


func current_dps() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	_hits = _hits.filter(func(h: Array) -> bool: return now - h[0] <= DPS_WINDOW)
	var total := 0.0
	for h: Array in _hits:
		total += h[1]
	return total / DPS_WINDOW


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		if _flash <= 0.0:
			queue_redraw()
	var dps := current_dps()
	_label.text = "DPS %d" % roundi(dps) if dps > 0.0 else ""


const SPRITE_PATH: String = "res://art/sprites/objects/training_dummy.png"
const SPRITE_SIZE: Vector2 = Vector2(24, 34)  ## 絵の大きさ。足元の中心が原点
const FLASH_TINT := Color(3.0, 3.0, 3.0, 1.0)  ## 被弾の点滅（明るく飛ばす）
static var _texture: Texture2D


func _draw() -> void:
	draw_rect(Rect2(-7, -2, 14, 4), SHADOW)
	if _texture == null:
		_texture = load(SPRITE_PATH) as Texture2D
	if _texture == null:
		return
	var tint: Color = FLASH_TINT if _flash > 0.0 else Color.WHITE
	draw_texture(_texture, Vector2(-SPRITE_SIZE.x * 0.5, -SPRITE_SIZE.y), tint)
