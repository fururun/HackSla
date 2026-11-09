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

const CRYPT_TALL_PATH: String = "res://art/tiles/crypt_walls_tall.png"  ## 地下墓所の、2階分の高い壁（32×48 を6種類）
const TALL_WALL_H: int = 48
const TALL_SOURCE: int = 1
const HD_TALL_PATH: String = "res://art/tiles/crypt_walls_tall_hd.png"  ## 壁を2倍の細かさで（64×96 を6種類）
const HD_LOW_PATH: String = "res://art/tiles/crypt_walls_low_hd.png"    ## 低い壁（64×64 を3種類）
const CRYPT_ART_PATH: String = "res://art/tiles/crypt_tiles.png"  ## 地下墓所（暗い遺跡）のドット絵
const TILE_ART_PATH: String = "res://art/tiles/grounds_tiles.png"  ## 廃寺の境内（屋外）の、床と壁のドット絵（地下墓所用は crypt_tiles.png）
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
const FOREST_MARGIN: int = 10  ## マップの外側に敷く森の厚さ（マス）
const FOREST_BG := Color("#16301f")
const HIGH_WALL_HEIGHT: float = 16.0
const LOW_WALL_HEIGHT: float = 4.0

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var _sort_parent: Node2D
var _hd_tall: Texture2D
var _hd_low: Texture2D
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
	_sort_parent = y_sorted_parent
	if hd_walls and ResourceLoader.exists(HD_TALL_PATH) and ResourceLoader.exists(HD_LOW_PATH):
		_hd_tall = load(HD_TALL_PATH)
		_hd_low = load(HD_LOW_PATH)

	markers.clear()
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			var cell := Vector2i(x, y)
			if c == "#":
				var kind := _wall_kind(rows, x, y)
				if kind != Vector2i(-1, -1):
					_set_wall(cell, kind, wall_variant(cell, kind == WALL))
				continue
			floor_layer.set_cell(cell, 0, floor_tile(cell))
			if c != ".":
				if not markers.has(c):
					markers[c] = []
				markers[c].append(floor_layer.map_to_local(cell))
	_add_floor_mural(rows)
	if art_path == TILE_ART_PATH:  # 屋外だけ、外側を森で埋める（地下は暗がりのまま）
		_build_forest_margin(rows)
	RenderingServer.set_default_clear_color(FOREST_BG if art_path == TILE_ART_PATH else Color("#080e1f"))


## マップ全体の床の絵を敷く。床のタイルは、当たり判定・印の位置のために残して、見えなくする
func _add_floor_mural(rows: PackedStringArray) -> void:
	if mural_path == "" or not ResourceLoader.exists(mural_path):
		return
	var texture: Texture2D = load(mural_path)
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "FloorMural"
	sprite.texture = texture
	sprite.centered = false
	sprite.position = Vector2(-(rows.size() - 1) * 16, 0)  # 絵の左の余白（make_floor_mural.py の OX）
	var cols: int = 0
	for r: String in rows:
		cols = maxi(cols, r.length())
	sprite.scale = Vector2.ONE * (float((cols + rows.size()) * 16) / texture.get_width())  # 細かい絵（2倍など）は、縮めて重ねる
	sprite.z_index = -9
	add_child(sprite)
	floor_layer.visible = false


## マップの外側にも、見た目だけの森（木・岩・茂み）を厚く敷く。画面の端が真っ暗にならないように
func _build_forest_margin(rows: PackedStringArray) -> void:
	var width: int = 0
	for r: String in rows:
		width = maxi(width, r.length())
	var height: int = rows.size()
	for y in range(-FOREST_MARGIN, height + FOREST_MARGIN):
		for x in range(-FOREST_MARGIN, width + FOREST_MARGIN):
			if _is_floor(rows, x, y) or wall_layer.get_cell_source_id(Vector2i(x, y)) != -1:
				continue
			var near: bool = false
			for dy in range(-FOREST_MARGIN, FOREST_MARGIN + 1):
				for dx in range(-FOREST_MARGIN, FOREST_MARGIN + 1):
					if _is_floor(rows, x + dx, y + dy):
						near = true
						break
				if near:
					break
			if not near:
				continue
			# 高い木は、上に重なって見える床（画面の上側＝x-,y-）が近くにないときだけ
			var low: bool = false
			for a in range(0, 4):
				for b in range(0, 4):
					if _is_floor(rows, x - a, y - b):
						low = true
			var cell := Vector2i(x, y)
			wall_layer.set_cell(cell, 0, (LOW_WALL if low else WALL) + Vector2i(0, wall_variant(cell, not low)))


## 壁の見た目の種類（木・針葉樹・大木・岩山 / 茂み・花の茂み・低い岩）を、座標から固定で選ぶ
static func wall_variant(cell: Vector2i, high: bool) -> int:
	var seed_value: int = (cell.x * 92837111) ^ (cell.y * 689287499)
	var r: int = posmod(seed_value ^ (seed_value >> 9), 100)
	if art_path == CRYPT_ART_PATH:
		# 地下墓所：高い壁 0=普通 1=アーチ 2=窓 3=扉 4=崩れ 5=苔 / 低い壁 0=普通 1=崩れ 2=苔
		if high:
			return 0 if r < 40 else (1 if r < 50 else (2 if r < 62 else (3 if r < 70 else (4 if r < 85 else 5))))
		return 0 if r < 55 else (1 if r < 80 else 2)
	if high:
		return 0 if r < 40 else (1 if r < 65 else (2 if r < 85 else 3))
	return 0 if r < 45 else (1 if r < 70 else 2)


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
	var art: Image = _load_tile_art(img.get_size())
	if art != null:
		img = art  # ドット絵のタイルがあれば、コードで描いた仮の絵のかわりに使う

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(Iso.TILE_W, Iso.TILE_W)
	ts.add_source(src, 0)
	var coords: Array[Vector2i] = [WALL, LOW_WALL]
	for v in range(1, 6):
		coords.append(WALL + Vector2i(0, v))
	for v in range(1, 3):
		coords.append(LOW_WALL + Vector2i(0, v))
	for variant: int in FLOOR_VARIANTS:
		coords.append(Vector2i(0, variant))
		coords.append(Vector2i(1, variant))
	for coord: Vector2i in coords:
		src.create_tile(coord)
		var data := src.get_tile_data(coord, 0)
		data.texture_origin = Vector2i(0, Iso.TILE_H / 2)
	for coord: Vector2i in [WALL, LOW_WALL, WALL + Vector2i(0, 1), WALL + Vector2i(0, 2), WALL + Vector2i(0, 3), WALL + Vector2i(0, 4), WALL + Vector2i(0, 5),
			LOW_WALL + Vector2i(0, 1), LOW_WALL + Vector2i(0, 2)]:
		var wall := src.get_tile_data(coord, 0)
		if hd_walls:
			wall.modulate = Color(1, 1, 1, 0)  # 見た目は、細かい絵のスプライトに任せる
		wall.add_collision_polygon(0)
		wall.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-16, 0), Vector2(0, -8), Vector2(16, 0), Vector2(0, 8)]))
	if art_path == CRYPT_ART_PATH and ResourceLoader.exists(CRYPT_TALL_PATH):
		# 2階分の高い壁（32×48）。足もとの菱形は、床と同じ位置
		var tall_tex: Texture2D = load(CRYPT_TALL_PATH)
		if tall_tex != null and tall_tex.get_size() == Vector2(Iso.TILE_W * 6, TALL_WALL_H):
			var tall := TileSetAtlasSource.new()
			tall.texture = tall_tex
			tall.texture_region_size = Vector2i(Iso.TILE_W, TALL_WALL_H)
			ts.add_source(tall, TALL_SOURCE)
			for v in 6:
				tall.create_tile(Vector2i(v, 0))
				var td := tall.get_tile_data(Vector2i(v, 0), 0)
				td.texture_origin = Vector2i(0, 16)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-16, 0), Vector2(0, -8), Vector2(16, 0), Vector2(0, 8)]))
	return ts


## 壁のセルの絵を置く。地下墓所で高い壁なら、2階分の高い壁（なければ今までの壁）
func _set_wall(cell: Vector2i, kind: Vector2i, variant: int) -> void:
	if _hd_tall != null and _hd_low != null:
		# 細かい絵のスプライトで見せる。タイルは、見えなくして当たり判定だけ残す
		wall_layer.set_cell(cell, 0, kind)
		var high: bool = kind == WALL
		var tex: Texture2D = _hd_tall if high else _hd_low
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		var w: int = Iso.TILE_W * 2
		atlas.region = Rect2(variant * w, 0, w, tex.get_height())
		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.scale = Vector2(0.5, 0.5)
		sprite.offset = Vector2(0, -32 if high else -16)  # 足もとの菱形の中心を、マスの中心に合わせる
		sprite.position = floor_layer.map_to_local(cell)
		_sort_parent.add_child.call_deferred(sprite)
	elif kind == WALL and wall_layer.tile_set.has_source(TALL_SOURCE):
		wall_layer.set_cell(cell, TALL_SOURCE, Vector2i(variant, 0))
	else:
		wall_layer.set_cell(cell, 0, kind + Vector2i(0, variant))


## ドット絵のタイル（tools/tiles/make_crypt_tiles.py が作る）。大きさが合わない・なければ null（コードで描いた絵のまま）
static var hd_walls: bool = false  ## true なら、壁を2倍の細かさの絵（スプライト）で見せる。タイルは当たり判定だけ残す
static var mural_path: String = ""  ## マップ全体の床の絵（あれば、床のタイルの上に敷く。tools/tiles/make_floor_mural.py）
static var art_path: String = TILE_ART_PATH  ## 使うタイル絵。エリアの見た目の切り替え用


static func _load_tile_art(expected: Vector2i) -> Image:
	if not ResourceLoader.exists(art_path):
		return null
	var texture: Texture2D = load(art_path)
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.get_size() != expected:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


## 座標だけから固定の模様を選ぶ。乱数状態・生成順には依存しない。
static func floor_tile(cell: Vector2i) -> Vector2i:
	var seed_value: int = (cell.x * 73856093) ^ (cell.y * 19349663)
	var fine: int = posmod(seed_value ^ (seed_value >> 7), 100)
	# 粗い区画ごとに、土（5）や石畳（6）の場所をまとめる。ほかは草（0〜3）に、花（4）と土まじり（7）を少し
	var bx: int = floori(cell.x / 4.0)
	var by: int = floori(cell.y / 4.0)
	var block_seed: int = (bx * 83492791) ^ (by * 2654435761)
	var block: int = posmod(block_seed ^ (block_seed >> 11), 100)
	var variant: int
	if block < 9:
		variant = 5 if fine < 85 else fine % 4
	elif block < 18:
		variant = 6 if fine < 85 else 5
	elif fine < 6:
		variant = 4
	else:
		variant = fine % 4
	return Vector2i(posmod(cell.x + cell.y, 2), variant)


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
