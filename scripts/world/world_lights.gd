class_name WorldLights
extends Node2D
## 光だまり：マップの壁ぎわ・開始位置・宝箱・ボスの近くに、たいまつ（と色つきの灯り）を置く。
## 全体は CanvasModulate で暗くし、PointLight2D でその周りだけ明るくする。見た目だけ（当たり判定なし）。

const AMBIENT := Color("#7d82ad")          ## 画面全体の明るさ（暗い青紫）
const TORCH_EVERY: int = 46                 ## 壁ぎわの床のうち、およそこの数マスにつき1本
const WARM := Color("#ffa24a")
const COOL := Color("#4ad6b4")
const PINK := Color("#d96aa8")

var _lights: Array[PointLight2D] = []
var _phases: Array[float] = []
var _time: float = 0.0
var _glow_texture: GradientTexture2D


func build(rows: PackedStringArray, map: IsoMap) -> void:
	var mod := CanvasModulate.new()
	mod.color = AMBIENT
	add_child(mod)

	_glow_texture = GradientTexture2D.new()
	_glow_texture.fill = GradientTexture2D.FILL_RADIAL
	_glow_texture.fill_from = Vector2(0.5, 0.5)
	_glow_texture.fill_to = Vector2(1.0, 0.5)
	_glow_texture.width = 128
	_glow_texture.height = 128
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	_glow_texture.gradient = grad

	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				continue
			var cell := Vector2i(x, y)
			if not _near_wall(rows, x, y):
				continue
			var h: int = posmod(((x * 73856093) ^ (y * 19349663)) >> 3, TORCH_EVERY)
			if h != 0:
				continue
			_add_torch(map.floor_layer.map_to_local(cell), _color_for(cell))
	# 目印の近くにも、少し大きな灯り（開始・宝箱・ボス）
	_add_pool(map.marker("P"), WARM, 1.6, 0.8)
	for pos: Vector2 in map.markers.get("C", []):
		_add_pool(pos, Color("#ffd27a"), 1.0, 0.8)
	for pos: Vector2 in map.markers.get("X", []):
		_add_pool(pos, PINK, 2.4, 1.0)


func _near_wall(rows: PackedStringArray, x: int, y: int) -> bool:
	for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + off.x
		var ny: int = y + off.y
		if ny < 0 or ny >= rows.size() or nx < 0 or nx >= rows[ny].length() or rows[ny][nx] == "#":
			return true
	return false


func _color_for(cell: Vector2i) -> Color:
	var r: int = posmod((cell.x * 31 + cell.y * 17) % 10, 10)
	return WARM if r < 7 else (COOL if r < 9 else PINK)


func _add_pool(pos: Vector2, color: Color, size: float, energy: float) -> void:
	if pos == Vector2.ZERO:
		return
	var light := PointLight2D.new()
	light.texture = _glow_texture
	light.texture_scale = size
	light.color = color
	light.energy = energy
	light.position = pos
	add_child(light)


func _add_torch(pos: Vector2, color: Color) -> void:
	var light := PointLight2D.new()
	light.texture = _glow_texture
	light.texture_scale = 1.5
	light.color = color
	light.energy = 1.1
	light.position = pos + Vector2(0, -8)
	add_child(light)
	_lights.append(light)
	_phases.append(randf() * TAU)
	# たいまつの絵：細い柱と、炎の先
	var torch := Sprite2D.new()
	torch.texture = _torch_texture(color)
	torch.position = pos + Vector2(0, -6)
	torch.z_index = 2
	add_child(torch)


static func _torch_texture(flame: Color) -> ImageTexture:
	var img := Image.create(7, 14, false, Image.FORMAT_RGBA8)
	var wood := Color("#5a3a22")
	for y in range(6, 14):
		img.set_pixel(3, y, wood)
	for y in range(3, 8):
		for x in range(2, 5):
			img.set_pixel(x, y, flame.lerp(Color.WHITE, 0.15))
	img.set_pixel(3, 2, flame.lerp(Color.WHITE, 0.6))
	img.set_pixel(3, 3, Color("#fff3c0"))
	img.set_pixel(3, 4, Color("#fff3c0"))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_time += delta
	for i in _lights.size():
		_lights[i].energy = 1.0 + 0.18 * sin(_time * 7.0 + _phases[i]) + 0.08 * sin(_time * 13.0 + _phases[i] * 2.0)
