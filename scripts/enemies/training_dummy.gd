class_name TrainingDummy
extends Node2D
## 案山子：倒れない練習用の的。ダメージの数字と、直近5秒の平均ダメージ（DPS）を出す。
## スキル・補助ジェム・チェインを試す場所として、拠点にも置く予定。

const DPS_WINDOW: float = 5.0

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
	_flash = 0.08
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
		_flash -= delta
	var dps := current_dps()
	_label.text = "DPS %d" % roundi(dps) if dps > 0.0 else ""
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	var wood := Color("#a0784f") if _flash <= 0.0 else Color.WHITE
	draw_rect(Rect2(-1, -22, 2, 22), wood.darkened(0.2))   # 支柱
	draw_rect(Rect2(-8, -18, 16, 3), wood)                 # 腕
	draw_rect(Rect2(-4, -17, 8, 10), Color("#c9b27a") if _flash <= 0.0 else Color.WHITE)  # わら
	draw_circle(Vector2(0, -24), 4.0, Color("#d8c08a") if _flash <= 0.0 else Color.WHITE)  # 頭
