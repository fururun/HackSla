class_name DebugOverlayTests
extends SceneTree
## 許可範囲内の統合テスト。--headless --script res://scripts/debug/test_debug_overlay.gd

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var overlay: CanvasLayer = root.get_node("DebugOverlay") as CanvasLayer
	var stats: Label = overlay.get_node("stats") as Label
	var result: Label = overlay.get_node("reload_result") as Label
	var db: Node = root.get_node("DataDB")
	_check(not stats.visible, "初期状態は非表示")
	await _key(KEY_F2)
	_check(get_nodes_in_group("enemies").is_empty(), "プレイヤー不在でも安全")
	await _key(KEY_F1)
	_check(stats.visible and "Player: --" in stats.text, "F1とプレイヤー不在表示")
	await _key(KEY_F1, true)
	_check(stats.visible, "キーリピートを無視")
	await _key(KEY_F1, false, false)
	_check(stats.visible, "キーを離しても切り替えない")

	var main: Node2D = load("res://scenes/main/main.tscn").instantiate() as Node2D
	root.add_child(main)
	for i: int in 10:
		await process_frame
	var player: Node2D = get_first_node_in_group("player") as Node2D
	# 親の変換とカメラがあっても、マウスのワールド位置に置けることを確認。
	var world: Node2D = player.get_parent() as Node2D
	var camera: Camera2D = player.get_viewport().get_camera_2d()
	camera.position_smoothing_enabled = false
	world.position = Vector2(30, -20)
	world.scale = Vector2(1.5, 1.5)
	await process_frame
	camera.force_update_scroll()
	var expected: Vector2 = player.get_global_mouse_position()
	var count: int = get_nodes_in_group("enemies").size()
	await _key(KEY_F2)
	var enemies: Array[Node] = get_nodes_in_group("enemies")
	_check(enemies.size() == count + 1, "F2で1体だけ追加")
	var dummy: TrainingDummy = enemies.back() as TrainingDummy
	_check(dummy != null and dummy.get_parent() == world, "案山子の型と親")
	_check(dummy.global_position.is_equal_approx(expected), "変換済みワールド座標に配置")
	await _key(KEY_F2, true)
	_check(get_nodes_in_group("enemies").size() == count + 1, "F2リピートで増えない")
	_check("Enemies: %d" % (count + 1) in stats.text, "敵数を更新")
	_check("Player: (%.1f, %.1f)" % [player.global_position.x, player.global_position.y] in stats.text,
		"プレイヤー位置を更新")
	_check("FPS:" in stats.text and "Data errors: 0" in stats.text, "FPSとエラー数")
	_check(stats.get_theme_font_size("font_size") == 8
		and stats.mouse_filter == Control.MOUSE_FILTER_IGNORE, "小さい表示とマウス透過")

	await _key(KEY_F1)
	_check(not stats.visible, "F1で非表示に戻る")
	var original: SkillDef = db.call("skill", "slash") as SkillDef
	original.name = "reload_test"
	await _key(KEY_F3)
	_check((db.call("skill", "slash") as SkillDef).name != "reload_test", "F3でJSONを再読み込み")
	_check(not stats.visible and result.visible and result.text == "Data reload: 0 errors",
		"非表示中にも結果を表示")
	await create_timer(1.0).timeout
	_check(result.visible, "1秒後は表示中")
	await _key(KEY_F3)
	await create_timer(1.2).timeout
	_check(result.visible, "連打時は最後の再読み込みから2秒表示")
	await create_timer(0.9).timeout
	_check(not result.visible, "2秒後に結果を消す")
	main.queue_free()
	await process_frame
	await _key(KEY_F1)
	_check("Player: --" in stats.text and "Enemies: 0" in stats.text, "シーン解放後も安全")
	print("== DebugOverlay: 成功 %d / 失敗 %d ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _key(code: Key, echo: bool = false, pressed: bool = true) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: " + message)
