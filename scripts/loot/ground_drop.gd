class_name GroundDrop
extends Node2D
## 描画だけを担当し、更新と回収は LootDirector にまとめる。
const NAME_RADIUS: float = 90.0
var _name_label: Label
var _item_name: String = ""

var value: Variant
var age: float = 0.0
var tint: Color = Color.WHITE
var beam: bool = false

func activate(payload: Variant, at: Vector2) -> void:
	value = payload
	_item_name = payload.display_name() if payload is ItemInstance else ""
	if _name_label != null:
		_name_label.hide()
		_name_label.text = _item_name
		_name_label.add_theme_color_override("font_color", payload.rarity.color if payload is ItemInstance else Color.WHITE)
	age = 0.0
	beam = payload is ItemInstance and payload.rarity.beam
	tint = payload.rarity.color if payload is ItemInstance else Color("66d9ee")
	if payload is int:
		tint = Color("ffd36a")
	global_position = at
	reset_physics_interpolation()  # 使い回しの瞬間移動で、前の場所から滑ってこないように
	show()
	queue_redraw()

func deactivate() -> void:
	value = null
	if _name_label != null:
		_name_label.hide()
	beam = false
	hide()

## ラベルは初めて近づいた時だけ作り、プール再利用時まで保持する。
func update_name_visibility(player_position: Vector2) -> void:
	var nearby: bool = value is ItemInstance and Iso.ground_distance(global_position, player_position) <= NAME_RADIUS
	if nearby and _name_label == null:
		_name_label = Label.new()
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_label.add_theme_font_size_override("font_size", 7)
		_name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		_name_label.add_theme_constant_override("shadow_outline_size", 2)
		_name_label.text = _item_name
		_name_label.add_theme_color_override("font_color", tint)
		add_child(_name_label)
	if _name_label != null:
		if nearby:
			_name_label.position = Vector2(-_name_label.get_minimum_size().x * 0.5, -22)
		_name_label.visible = nearby

func _draw() -> void:
	if value == null:
		return
	draw_ellipse_shadow()
	if value is ItemInstance:
		_draw_pillar()
	if value is ItemInstance:
		# 装備はレアリティの色の台座を敷く（絵だけだと、レアリティが地面から分からない）
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 6.5, Color(tint, 0.55))
		draw_set_transform(Vector2.ZERO)
	var tex := _icon(value)
	if tex != null:
		draw_texture(tex, Vector2(-ICON_SIZE * 0.5, -ICON_SIZE + 1.0))


const PILLAR_BASE_HEIGHT: float = 44.0  ## 光の柱の高さ（コモン）。レアリティが1段階上がるごとに PILLAR_STEP_HEIGHT だけ高くなる
const PILLAR_STEP_HEIGHT: float = 14.0
const PILLAR_BASE_WIDTH: float = 3.0  ## 柱の半幅（コモン）。段階ごとに PILLAR_STEP_WIDTH だけ太くなる
const PILLAR_STEP_WIDTH: float = 0.8


## 装備が落ちているところに、レアリティの色の光の柱を立てる（上へ向かって透けていく。高いレアリティほど高く、太く、明るい）
func pillar_height() -> float:
	var tier: int = (value as ItemInstance).rarity.tier if value is ItemInstance else 0
	return PILLAR_BASE_HEIGHT + PILLAR_STEP_HEIGHT * float(tier)


func _draw_pillar() -> void:
	var item: ItemInstance = value
	var tier: float = float(item.rarity.tier)
	var h: float = pillar_height()
	var half: float = PILLAR_BASE_WIDTH + PILLAR_STEP_WIDTH * tier
	var strength: float = 0.5 + 0.1 * tier  # 根もとの濃さ
	var color: Color = item.rarity.color
	# 外側のにじみ（太く、うすい）→ 柱の本体 → 芯（細く、白っぽい）。どれも上へ向かって消える
	_gradient_quad(half * 1.9, h, Color(color, strength * 0.28))
	_gradient_quad(half, h, Color(color, strength * 0.6))
	_gradient_quad(maxf(half * 0.28, 0.8), h * 0.9, Color(color.lightened(0.6), minf(strength + 0.3, 1.0)))
	# 根もとに、地面に広がる光の輪
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, half * 2.2, Color(color, 0.25))
	draw_set_transform(Vector2.ZERO)


func _gradient_quad(half_width: float, height: float, bottom_color: Color) -> void:
	var pts := PackedVector2Array([Vector2(-half_width, -2), Vector2(half_width, -2), Vector2(half_width * 0.6, -height), Vector2(-half_width * 0.6, -height)])
	var top_color := Color(bottom_color, 0.0)
	draw_polygon(pts, PackedColorArray([bottom_color, bottom_color, top_color, top_color]))


const ICON_DIR: String = "res://art/sprites/icons/"
const ICON_SIZE: float = 14.0
static var _icons: Dictionary = {}  ## 名前 -> Texture2D


## 落ちているものの種類から、アイコンを選ぶ（スキルジェム・補助ジェム・剣・防具・指輪・硬貨）
static func icon_name(payload: Variant) -> String:
	if payload is GemInstance:
		return "gem_support" if payload.kind == GemInstance.Kind.SUPPORT else "gem_skill"
	if payload is ItemInstance:
		match str(payload.base.slot):
			"weapon": return "sword"
			"ring", "amulet": return "ring"
			_: return "armor"
	return "coin"


static func _icon(payload: Variant) -> Texture2D:
	var n := icon_name(payload)
	if not _icons.has(n):
		_icons[n] = load(ICON_DIR + "icon_%s.png" % n) as Texture2D
	return _icons[n]

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
