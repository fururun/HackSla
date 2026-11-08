class_name Hud
extends CanvasLayer
## HUD：左下に体力の棒とレベル・経験値の棒。レベルアップと死亡のメッセージ。

const FONT_SIZE: int = UiStyle.FONT_STANDARD
const BAR_W: float = 120.0
const BAR_H: float = 14.0
const MARGIN: float = 6.0
const SCREEN_H: float = 270.0
const TEXT_COLOR: Color = UiStyle.TEXT
const BAR_BG: Color = UiStyle.BAR_BG
const LIFE_COLOR: Color = UiStyle.LIFE
const XP_COLOR: Color = UiStyle.XP
const LEVELUP_TIME: float = 1.5

var _vitals: PlayerVitals
var _root: Control
var _life_bar: Panel
var _life_label: Label
var _xp_bar: Panel
var _xp_label: Label
var _levelup_label: Label
var _dead_label: Label
var _levelup_t: float = 0.0
var _pulse_time: float = 0.0
const LOW_LIFE_RATIO: float = 0.3
const PULSE_PERIOD: float = 0.6


func setup(vitals: PlayerVitals) -> void:
	_vitals = vitals
	_build()
	vitals.changed.connect(_refresh)
	vitals.leveled_up.connect(_on_leveled_up)
	_refresh()


func _build() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	_root.theme = theme
	add_child(_root)
	_life_bar = _make_bar(Vector2(MARGIN, SCREEN_H - MARGIN - BAR_H * 2 - 3), LIFE_COLOR)
	_life_label = _make_label(_life_bar)
	_xp_bar = _make_bar(Vector2(MARGIN, SCREEN_H - MARGIN - BAR_H), XP_COLOR)
	_xp_label = _make_label(_xp_bar)
	_levelup_label = _make_message("レベルアップ！", UiStyle.ACCENT, Vector2(200, 70))
	_dead_label = _make_message("やられた　F5 でやり直し", UiStyle.WARNING, Vector2(170, 130))


func _make_message(text: String, color: Color, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	UiStyle.label(label, UiStyle.FONT_HEADING, color)
	label.position = pos
	label.visible = false
	_root.add_child(label)
	return label


## 背景つきの棒。子の "fill" が中身
func _make_bar(pos: Vector2, color: Color) -> Panel:
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiStyle.bar_background())
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = pos
	bg.size = Vector2(BAR_W, BAR_H)
	var fill := ColorRect.new()
	fill.name = "fill"
	fill.color = color
	fill.position = Vector2(1, 1)
	fill.size = Vector2(BAR_W - 2, BAR_H - 2)
	bg.add_child(fill)
	var light: ColorRect = ColorRect.new()
	light.name = "light"
	light.color = color.lightened(0.22)
	light.size = Vector2(BAR_W - 2, (BAR_H - 2) / 2)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(light)
	_root.add_child(bg)
	return bg


func _make_label(bar: Panel) -> Label:
	var label := Label.new()
	UiStyle.label(label)
	label.position = Vector2(4, -1)
	bar.add_child(label)
	return label


func _set_fill(bar: Panel, ratio: float) -> void:
	var fill: ColorRect = bar.get_node("fill")
	fill.size.x = (BAR_W - 2) * clampf(ratio, 0.0, 1.0)
	(fill.get_node("light") as ColorRect).size.x = fill.size.x


func _refresh() -> void:
	var max_life: float = _vitals.max_life()
	_set_fill(_life_bar, _vitals.life / max_life if max_life > 0.0 else 0.0)
	_life_label.text = "%d / %d" % [ceili(_vitals.life), roundi(max_life)]
	if _vitals.level >= LevelCurve.MAX_LEVEL:
		_set_fill(_xp_bar, 1.0)
		_xp_label.text = "Lv %d (MAX)" % _vitals.level
	else:
		var need: int = LevelCurve.xp_to_next(_vitals.level)
		_set_fill(_xp_bar, float(_vitals.xp) / float(need))
		_xp_label.text = "Lv %d  %d / %d" % [_vitals.level, _vitals.xp, need]
	_dead_label.visible = _vitals.is_dead()


func _on_leveled_up(_level: int) -> void:
	_levelup_label.visible = true
	_levelup_t = LEVELUP_TIME


func _process(delta: float) -> void:
	if _vitals != null and _life_bar != null:
		_pulse_time = fmod(_pulse_time + delta, PULSE_PERIOD)
		var low: bool = _vitals.life > 0.0 and _vitals.life <= _vitals.max_life() * LOW_LIFE_RATIO
		var pulse: float = (sin(_pulse_time / PULSE_PERIOD * TAU) + 1.0) * 0.5 if low else 0.0
		var color: Color = LIFE_COLOR.lerp(UiStyle.WARNING, pulse)
		var fill: ColorRect = _life_bar.get_node("fill")
		fill.color = color
		(fill.get_node("light") as ColorRect).color = color.lightened(0.22)
	if _levelup_t > 0.0:
		_levelup_t -= delta
		if _levelup_t <= 0.0:
			_levelup_label.visible = false
