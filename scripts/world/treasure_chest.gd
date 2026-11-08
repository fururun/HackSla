class_name TreasureChest
extends Node2D
## 宝箱。プレイヤーが近づくと開いて、1回だけ中身（ドロップ）を出す。
## 中身を出すのは LootDirector（opened 信号を受けて drop_chest を呼ぶ）。絵は仮（コードで描く）。

signal opened(chest: TreasureChest)

const OPEN_RADIUS: float = 20.0  ## 地面の距離（Iso.ground_distance）

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
	var wood := Color("#8a5a2b")
	var dark := Color("#5e3b1a")
	var gold := Color("#e0b83c")
	draw_rect(Rect2(-8, -9, 16, 9), wood)  # 箱の本体
	draw_rect(Rect2(-8, -9, 16, 2), dark)
	draw_rect(Rect2(-1, -6, 2, 4), gold)  # 錠前
	if is_open:
		draw_rect(Rect2(-8, -16, 16, 4), dark)  # 開いた蓋（後ろに倒れている）
		draw_rect(Rect2(-6, -9, 12, 3), Color("#2a1a0c"))  # 空の中
	else:
		draw_rect(Rect2(-8, -14, 16, 5), wood.lightened(0.1))  # 閉じた蓋
		draw_rect(Rect2(-8, -14, 16, 1), gold)
