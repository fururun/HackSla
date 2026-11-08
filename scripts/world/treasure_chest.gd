class_name TreasureChest
extends Node2D
## 宝箱。プレイヤーが近づくと開いて、1回だけ中身（ドロップ）を出す。
## 中身を出すのは LootDirector（opened 信号を受けて drop_chest を呼ぶ）。絵は仮（コードで描く）。

signal opened(chest: TreasureChest)

const OPEN_RADIUS: float = 20.0  ## 地面の距離（Iso.ground_distance）
const SPRITE_DIR: String = "res://art/sprites/objects/"
const SPRITE_SIZE: Vector2 = Vector2(30, 26)  ## 絵の大きさ。足元の中心が原点
static var _textures: Dictionary = {}  ## closed / open -> Texture2D

var is_open: bool = false
var legend: bool = false  ## レジェンドの宝箱（金色に光る。開けると、レジェンド以上の装備が出る）
var _age: float = 0.0


func _ready() -> void:
	add_to_group("chests")


func _physics_process(delta: float) -> void:
	if legend and not is_open:
		_age += delta
		queue_redraw()  # 光の柱を、ゆらす
	if is_open:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and Iso.ground_distance(global_position, player.global_position) <= OPEN_RADIUS:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	queue_redraw()
	opened.emit(self)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.35))  # 影
	draw_set_transform(Vector2.ZERO)
	var tex := _texture(is_open)
	if legend and not is_open:
		_draw_legend_glow()
	if tex != null:
		var tint: Color = Color(1.7, 1.35, 0.45) if legend else Color.WHITE  # 金色に染める
		draw_texture(tex, Vector2(-SPRITE_SIZE.x * 0.5, -SPRITE_SIZE.y), tint)


## 遠くからでも見える、金色の光の柱と、足元の光（ゆっくり脈打つ）
func _draw_legend_glow() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_age * 3.0)
	var color := Color("#ffb03d")
	var top: float = 120.0
	for layer: Array in [[12.0, 0.22], [6.0, 0.45], [2.0, 0.8]]:
		var half: float = float(layer[0])
		var alpha: float = float(layer[1]) * (0.7 + 0.3 * pulse)
		var pts := PackedVector2Array([Vector2(-half, -2), Vector2(half, -2), Vector2(half * 0.5, -top), Vector2(-half * 0.5, -top)])
		var bottom := Color(color.r, color.g, color.b, alpha)
		draw_polygon(pts, PackedColorArray([bottom, bottom, Color(bottom, 0.0), Color(bottom, 0.0)]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 16.0 + 3.0 * pulse, Color(color.r, color.g, color.b, 0.28))
	draw_set_transform(Vector2.ZERO)


static func _texture(open: bool) -> Texture2D:
	var key := "open" if open else "closed"
	if not _textures.has(key):
		_textures[key] = load(SPRITE_DIR + "chest_%s.png" % key) as Texture2D
	return _textures[key]
