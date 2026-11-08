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
		_name_label.add_theme_font_size_override("font_size", 8)
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
	if beam:
		draw_line(Vector2(0, -3), Vector2(0, -45), Color(tint, 0.22), 7.0)
		draw_line(Vector2(0, -3), Vector2(0, -45), tint.lightened(0.4), 1.0)
	if value is ItemInstance:
		# 装備はレアリティの色の台座を敷く（絵だけだと、レアリティが地面から分からない）
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 6.5, Color(tint, 0.55))
		draw_set_transform(Vector2.ZERO)
	var tex := _icon(value)
	if tex != null:
		draw_texture(tex, Vector2(-ICON_SIZE * 0.5, -ICON_SIZE + 1.0))


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
