class_name IsoMap
extends Node2D
## 文字で書いたマップから、斜め見下ろし視点の床と壁を作る（仮の絵はコードで描く）。
## ドット絵のタイルができたら、make_tileset() の中身を画像の読み込みに差し替える。
##
## マップの記号:
##   # 壁    . 床    P プレイヤーの開始位置    D 案山子
##   s 群れ小鬼の群れ（T08 で使う）    b 岩殻（T08 で使う）

const FLOOR_A := Vector2i(0, 0)
const FLOOR_B := Vector2i(1, 0)
const WALL := Vector2i(2, 0)      ## 奥の壁（高い）
const LOW_WALL := Vector2i(3, 0)  ## 手前の壁（低い縁。キャラを隠さないため）

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var markers: Dictionary = {}  ## 記号 -> Array[Vector2]（画面上の位置）


func build(rows: PackedStringArray, y_sorted_parent: Node2D) -> void:
	var ts := make_tileset()
	floor_layer = TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = ts
	floor_layer.z_index = -10
	add_child(floor_layer)

	# 壁はキャラと前後関係を比べるので、Y軸ソートする親（World）の下に置く
	wall_layer = TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = ts
	wall_layer.y_sort_enabled = true
	y_sorted_parent.add_child.call_deferred(wall_layer)

	markers.clear()
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			var cell := Vector2i(x, y)
			if c == "#":
				var kind := _wall_kind(rows, x, y)
				if kind != Vector2i(-1, -1):
					wall_layer.set_cell(cell, 0, kind)
				continue
			floor_layer.set_cell(cell, 0, FLOOR_A if (x + y) % 2 == 0 else FLOOR_B)
			if c != ".":
				if not markers.has(c):
					markers[c] = []
				markers[c].append(floor_layer.map_to_local(cell))


## 壁の種類を決める。床に接していない壁は描かない（-1,-1）。
## 床が画面の下側（x+1 か y+1）にある壁は「奥の壁」なので高く、それ以外は「手前の壁」なので低くする。
static func _wall_kind(rows: PackedStringArray, x: int, y: int) -> Vector2i:
	var behind := false
	var touches := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if _is_floor(rows, x + dx, y + dy):
				touches = true
				if dx >= 0 and dy >= 0:
					behind = true
	if not touches:
		return Vector2i(-1, -1)
	return WALL if behind else LOW_WALL


static func _is_floor(rows: PackedStringArray, x: int, y: int) -> bool:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return false
	return rows[y][x] != "#"


## その位置が床の上か（壁の中・マップの外は false）。
## margin が true なら、上下左右のマスもすべて床のときだけ true（壁ぎわを避ける。壁の絵に隠れないように）
func is_floor_at(global_pos: Vector2, margin: bool = false) -> bool:
	if floor_layer == null:
		return false
	var cell: Vector2i = floor_layer.local_to_map(floor_layer.to_local(global_pos))
	if floor_layer.get_cell_source_id(cell) == -1:
		return false
	if not margin:
		return true
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if floor_layer.get_cell_source_id(cell + offset) == -1:
			return false
	return true


func marker(c: String, index: int = 0) -> Vector2:
	var list: Array = markers.get(c, [])
	return list[index] if index < list.size() else Vector2.ZERO


static func make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(Iso.TILE_W, Iso.TILE_H)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)

	var img := Image.create(Iso.TILE_W * 4, Iso.TILE_W, false, Image.FORMAT_RGBA8)
	_paint_floor(img, 0, Color("#3a3d46"), Color("#30333b"))
	_paint_floor(img, Iso.TILE_W, Color("#363941"), Color("#2c2f37"))
	_paint_wall(img, Iso.TILE_W * 2, 16.0)
	_paint_wall(img, Iso.TILE_W * 3, 4.0)

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(Iso.TILE_W, Iso.TILE_W)
	ts.add_source(src, 0)
	for coord: Vector2i in [FLOOR_A, FLOOR_B, WALL, LOW_WALL]:
		src.create_tile(coord)
		var data := src.get_tile_data(coord, 0)
		data.texture_origin = Vector2i(0, Iso.TILE_H / 2)
	for coord: Vector2i in [WALL, LOW_WALL]:
		var wall := src.get_tile_data(coord, 0)
		wall.add_collision_polygon(0)
		wall.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-16, 0), Vector2(0, -8), Vector2(16, 0), Vector2(0, 8)]))
	return ts


## 32x32 の枠の下半分に、ひし形の床を描く
static func _paint_floor(img: Image, ox: int, fill: Color, edge: Color) -> void:
	for y in range(16, 32):
		for x in 32:
			var t := absf(x + 0.5 - 16.0) / 16.0 + absf(y + 0.5 - 24.0) / 8.0
			if t <= 1.0:
				img.set_pixel(ox + x, y, edge if t > 0.86 else fill)


## 32x32 の枠に、高さ height ドットの壁ブロックを描く（上面・左面・右面）
static func _paint_wall(img: Image, ox: int, height: float) -> void:
	var top := Color("#6a6f7d")
	var left := Color("#4a4e59")
	var right := Color("#3c3f49")
	var top_c := 24.0 - height  # 上面のひし形の中心
	for y in 32:
		for x in 32:
			var w := 1.0 - absf(x + 0.5 - 16.0) / 16.0  # 中央で1、端で0
			var top_lo := top_c - 8.0 * w
			var top_hi := top_c + 8.0 * w
			var bottom := 24.0 + 8.0 * w
			var py := y + 0.5
			if py >= top_lo and py <= top_hi:
				img.set_pixel(ox + x, y, top)
			elif py > top_hi and py <= bottom:
				img.set_pixel(ox + x, y, left if x < 16 else right)
