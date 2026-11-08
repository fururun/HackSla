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


func _draw() -> void:
	draw_rect(Rect2(-7, -2, 14, 4), SHADOW)
	var flash: bool = _flash > 0.0
	var edge: Color = Color.WHITE if flash else OUTLINE
	var wood: Color = Color.WHITE if flash else WOOD
	var straw: Color = Color.WHITE if flash else STRAW
	draw_rect(Rect2(-2, -24, 4, 25), edge)
	draw_rect(Rect2(-1, -23, 2, 23), wood)
	draw_rect(Rect2(-10, -19, 20, 5), edge)
	draw_rect(Rect2(-9, -18, 18, 3), wood)
	draw_rect(Rect2(-5, -19, 10, 13), edge)
	draw_rect(Rect2(-4, -18, 8, 11), straw)
	for x: int in range(-3, 4, 2):
		draw_rect(Rect2(x, -17, 1, 11), Color.WHITE if flash else STRAW_SHADE)
	draw_circle(Vector2(0, -25), 5, edge, true, -1.0, false)
	draw_circle(Vector2(0, -25), 4, Color.WHITE if flash else STRAW_LIGHT, true, -1.0, false)
	draw_rect(Rect2(-2, -28, 1, 5), straw)
	draw_rect(Rect2(1, -28, 1, 5), straw)
	draw_rect(Rect2(-2, -26, 1, 1), edge)
	draw_rect(Rect2(2, -26, 1, 1), edge)
	draw_rect(Rect2(-4, -11, 8, 2), wood)
