class_name DebugOverlayLayer
extends CanvasLayer
## F1: 情報表示、F2: マウス位置に案山子、F3: JSON再読み込み。
## 撮影時はユーザー引数 --debug-overlay で最初から表示できる。

const RELOAD_MESSAGE_SECONDS: float = 2.0

var _stats: Label
var _reload_result: Label
var _message_left: float = 0.0


func _ready() -> void:
	layer = 100
	# メイン画面の操作説明（y=4）の下に収める。
	_stats = _make_label("stats", Vector2(6, 18))
	_reload_result = _make_label("reload_result", Vector2(6, 60))
	_stats.visible = OS.get_cmdline_user_args().has("--debug-overlay")
	_reload_result.hide()
	_update_stats()


func _make_label(node_name: String, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)
	return label


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if event.is_action_pressed("toggle_debug"):
		_stats.visible = not _stats.visible
		if _stats.visible:
			_update_stats()
	elif key.keycode == KEY_F2 or key.physical_keycode == KEY_F2:
		_spawn_dummy()
	elif key.keycode == KEY_F3 or key.physical_keycode == KEY_F3:
		DataDB.reload()
		_reload_result.text = "Data reload: %d errors" % DataDB.errors.size()
		_message_left = RELOAD_MESSAGE_SECONDS
		_reload_result.show()
		if _stats.visible:
			_update_stats()
	else:
		return
	get_viewport().set_input_as_handled()


func _spawn_dummy() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.get_parent() == null:
		return
	# プレイヤーのCanvas/Cameraを経由して画面座標をワールド座標へ変換する。
	var target: Vector2 = player.get_global_mouse_position()
	var dummy: TrainingDummy = TrainingDummy.new()
	player.get_parent().add_child(dummy)
	dummy.global_position = target


func _process(delta: float) -> void:
	if _stats.visible:
		_update_stats()
	if _message_left > 0.0:
		_message_left = maxf(0.0, _message_left - delta)
		if _message_left <= 0.0:
			_reload_result.hide()


func _update_stats() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var location: String = "--"
	if player != null:
		location = "(%.1f, %.1f)" % [player.global_position.x, player.global_position.y]
	_stats.text = "FPS: %d\nEnemies: %d\nPlayer: %s\nData errors: %d" % [
		Engine.get_frames_per_second(), get_tree().get_nodes_in_group("enemies").size(),
		location, DataDB.errors.size()]
