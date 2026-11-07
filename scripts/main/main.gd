extends Node2D
## テスト用のメイン画面：マップを作り、プレイヤーと案山子を置く。

const MAP_PATH: String = "res://data/maps/test_01.txt"

var world: Node2D
var map: IsoMap
var player: Player


func _ready() -> void:
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	map = IsoMap.new()
	map.name = "Map"
	add_child(map)
	move_child(map, 0)
	map.build(load_map(MAP_PATH), world)

	player = Player.new()
	player.name = "Player"
	player.position = map.marker("P")
	world.add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.offset = Vector2(0, -10)
	player.add_child(cam)

	for pos: Vector2 in map.markers.get("D", []):
		var dummy := TrainingDummy.new()
		dummy.position = pos
		world.add_child(dummy)

	_add_help()


static func load_map(path: String) -> PackedStringArray:
	var rows := PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if not line.strip_edges().is_empty():
			rows.append(line.strip_edges(false, true))
	return rows


func _add_help() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var help := Label.new()
	help.text = "WASD: 移動　左クリック: 斬撃（マウスの方向）"
	help.position = Vector2(6, 4)
	help.add_theme_font_size_override("font_size", 8)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	help.add_theme_constant_override("outline_size", 2)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(help)
