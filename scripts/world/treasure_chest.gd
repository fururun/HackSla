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


func _ready() -> void:
	add_to_group("chests")


func _physics_process(_delta: float) -> void:
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
	if tex != null:
		draw_texture(tex, Vector2(-SPRITE_SIZE.x * 0.5, -SPRITE_SIZE.y))


static func _texture(open: bool) -> Texture2D:
	var key := "open" if open else "closed"
	if not _textures.has(key):
		_textures[key] = load(SPRITE_DIR + "chest_%s.png" % key) as Texture2D
	return _textures[key]
