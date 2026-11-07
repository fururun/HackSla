class_name EnemyStressScene
extends Node2D
## 150体を一度だけ配置する負荷シーン。--benchmark でウォームアップ後5秒測定。

const ENEMY_COUNT: int = 150
const WARMUP_SECONDS: float = 1.0
const SAMPLE_SECONDS: float = 5.0

var manager: EnemyManager
var _label: Label
var _elapsed: float = 0.0
var _samples: int = 0
var _total_process: float = 0.0
var _reported: bool = false


func _ready() -> void:
	var world := Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	var map := IsoMap.new()
	add_child(map)
	move_child(map, 0)
	var rows := PackedStringArray()
	for line: String in FileAccess.get_file_as_string("res://data/maps/test_01.txt").split("\n"):
		if not line.strip_edges().is_empty():
			rows.append(line.strip_edges(false, true))
	map.build(rows, world)
	var player := Player.new()
	player.position = map.marker("s")
	world.add_child(player)
	var camera := Camera2D.new()
	camera.offset = Vector2(0, -10)
	player.add_child(camera)
	manager = EnemyManager.new()
	manager.y_sort_enabled = true
	world.add_child(manager)
	# 地面上の同心円に一度だけ配置。150体を画面内に収める。
	var def: EnemyDef = DataDB.enemy("swarmling")
	for i: int in ENEMY_COUNT:
		var angle: float = float(i) * 2.399963
		var radius: float = 16.0 + sqrt(float(i)) * 10.0
		manager.spawn(def, player.position + Vector2(cos(angle) * radius, sin(angle) * radius * 0.5))
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(6, 4)
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_label)


func _process(delta: float) -> void:
	_label.text = "FPS: %d  Enemies: %d\nWASD: Move / Click: Slash" % [Engine.get_frames_per_second(), manager.active_count()]
	if not OS.get_cmdline_user_args().has("--benchmark") or _reported:
		return
	_elapsed += delta
	if _elapsed < WARMUP_SECONDS:
		return
	_total_process += Performance.get_monitor(Performance.TIME_PROCESS)
	_samples += 1
	if _elapsed >= WARMUP_SECONDS + SAMPLE_SECONDS:
		_reported = true
		print("[stress] enemies=%d samples=%d seconds=%.3f TIME_PROCESS_mean_ms=%.6f headless=%s" % [manager.active_count(), _samples, _elapsed - WARMUP_SECONDS, _total_process * 1000.0 / _samples, DisplayServer.get_name() == "headless"])
		get_tree().quit()
