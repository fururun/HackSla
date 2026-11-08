class_name IsoMap
extends Node2D
## 文字で書いたマップから、斜め見下ろし視点の床と壁を作る（仮の絵はコードで描く）。
## ドット絵のタイルができたら、make_tileset() の中身を画像の読み込みに差し替える。
##
## マップの記号:
##   # 壁    . 床    P プレイヤーの開始位置    D 案山子    C 宝箱
##   s スライムの群れ（T08 で使う）    b 岩殻（T08 で使う）

const FLOOR_A := Vector2i(0, 0)
const FLOOR_B := Vector2i(1, 0)
const WALL := Vector2i(2, 0)      ## 奥の壁（高い）
const LOW_WALL := Vector2i(3, 0)  ## 手前の壁（低い縁。キャラを隠さないため）

const FLOOR_VARIANTS: int = 8
const FLOOR_COLORS: Array[Color] = [Color("#3a3d46"), Color("#363941")]
const FLOOR_EDGE := Color("#282c35")
const FLOOR_LIGHT := Color("#474c57")
const FLOOR_CRACK := Color("#292d36")
const STONE_LIGHT := Color("#555b66")
const WALL_TOP := Color("#656c79")
const WALL_LIGHT := Color("#89909a")
const WALL_LEFT := Color("#4a505c")
const WALL_RIGHT := Color("#3b414d")
const WALL_MORTAR := Color("#303640")
const HIGH_WALL_HEIGHT: float = 16.0
const LOW_WALL_HEIGHT: float = 4.0

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
			floor_layer.set_cell(cell, 0, floor_tile(cell))
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

	var img := Image.create(Iso.TILE_W * 4, Iso.TILE_W * FLOOR_VARIANTS, false, Image.FORMAT_RGBA8)
	for variant: int in FLOOR_VARIANTS:
		for shade: int in 2:
			_paint_floor(img, shade * Iso.TILE_W, variant * Iso.TILE_W, FLOOR_COLORS[shade], variant)
	_paint_wall(img, Iso.TILE_W * 2, HIGH_WALL_HEIGHT)
	_paint_wall(img, Iso.TILE_W * 3, LOW_WALL_HEIGHT)

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(Iso.TILE_W, Iso.TILE_W)
	ts.add_source(src, 0)
	var coords: Array[Vector2i] = [WALL, LOW_WALL]
	for variant: int in FLOOR_VARIANTS:
		coords.append(Vector2i(0, variant))
		coords.append(Vector2i(1, variant))
	for coord: Vector2i in coords:
		src.create_tile(coord)
		var data := src.get_tile_data(coord, 0)
		data.texture_origin = Vector2i(0, Iso.TILE_H / 2)
	for coord: Vector2i in [WALL, LOW_WALL]:
		var wall := src.get_tile_data(coord, 0)
		wall.add_collision_polygon(0)
		wall.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-16, 0), Vector2(0, -8), Vector2(16, 0), Vector2(0, 8)]))
	return ts


## 座標だけから固定の模様を選ぶ。乱数状態・生成順には依存しない。
static func floor_tile(cell: Vector2i) -> Vector2i:
	var seed_value: int = (cell.x * 73856093) ^ (cell.y * 19349663)
	return Vector2i(posmod(cell.x + cell.y, 2), posmod(seed_value ^ (seed_value >> 7), FLOOR_VARIANTS))


## 画像の整数ピクセルに焼き付けるので、実行中の描き直しは不要。
static func _paint_floor(img: Image, ox: int, oy: int, fill: Color, variant: int) -> void:
	for y: int in range(16, 32):
		for x: int in 32:
			var edge_distance: int = absi(x * 2 + 1 - 32) + absi(y * 2 + 1 - 48) * 2
			if edge_distance <= 32:
				var ink: Color = fill
				if edge_distance > 28:
					ink = FLOOR_LIGHT if y < 24 else FLOOR_EDGE
				img.set_pixel(ox + x, oy + y, ink)
	if variant < 4:
		return
	var shift: int = (variant - 4) * 2
	if variant % 2 == 0:
		for point: Vector2i in [Vector2i(10, 22), Vector2i(11, 23), Vector2i(12, 23), Vector2i(13, 24), Vector2i(13, 25), Vector2i(15, 23)]:
			img.set_pixel(ox + point.x + shift, oy + point.y, FLOOR_CRACK)
	else:
		img.set_pixel(ox + 10 + shift, oy + 24, STONE_LIGHT)
		img.set_pixel(ox + 11 + shift, oy + 24, STONE_LIGHT)
		img.set_pixel(ox + 10 + shift, oy + 25, FLOOR_CRACK)
		img.set_pixel(ox + 20, oy + 22, FLOOR_CRACK)


## 高さ・衝突・描画原点は従来通り。目地は側面だけに焼き付ける。
static func _paint_wall(img: Image, ox: int, height: float) -> void:
	var top_c: float = 24.0 - height
	for y: int in 32:
		for x: int in 32:
			var w: float = 1.0 - absf(x + 0.5 - 16.0) / 16.0
			var top_lo: float = top_c - 8.0 * w
			var top_hi: float = top_c + 8.0 * w
			var bottom: float = 24.0 + 8.0 * w
			var py: float = y + 0.5
			if py >= top_lo and py <= top_hi:
				img.set_pixel(ox + x, y, WALL_LIGHT if py < top_lo + 1.0 else WALL_TOP)
			elif py > top_hi and py <= bottom:
				var course_y: int = floori(py - top_hi)
				var course: int = course_y / 5
				var mortar: bool = course_y % 5 == 4 or posmod(x + course * 5, 10) == 0
				img.set_pixel(ox + x, y, WALL_MORTAR if mortar else (WALL_LEFT if x < 16 else WALL_RIGHT))
