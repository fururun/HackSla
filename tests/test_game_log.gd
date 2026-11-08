extends RefCounted
## 遊んだ記録・デバッグの記録

var t: Variant

const TEST_DIR: String = "user://test_game_log"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _clean() -> void:
	for f: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR.path_join(f)))


func test_writes_play_and_debug_lines() -> void:
	_clean()
	var log := GameLog.new()
	log.open(TEST_DIR)
	log.play("level_up", {"level": 3})
	log.debug("hello debug")
	log.close_logs()
	var play := _read(log.play_path)
	var debug := _read(log.debug_path)
	t.check(play.contains("start"), "遊んだ記録に、はじまりが書かれる")
	t.check(play.contains("level_up level=3"), "出来事とデータが書かれる")
	t.check(play.contains("summary"), "終わりに、まとめが書かれる")
	t.check(debug.contains("hello debug"), "デバッグの記録に書かれる")
	log.free()


func test_old_logs_are_rotated() -> void:
	_clean()
	for i in GameLog.KEEP_FILES + 5:
		var f := FileAccess.open("%s/play_2000%04d_000000.log" % [TEST_DIR, i], FileAccess.WRITE)
		f.store_line("old")
	var log := GameLog.new()
	log.open(TEST_DIR)
	var count := 0
	for f: String in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("play_"):
			count += 1
	t.check_eq(count, GameLog.KEEP_FILES, "遊んだ記録は、新しい順に決まった数だけ残る")
	t.check(FileAccess.file_exists(log.play_path), "いまのファイルは消えない")
	log.close_logs()
	log.free()


func test_tools_and_tests_do_not_use_the_real_log_dir() -> void:
	t.check_eq(GameLog.default_dir(), GameLog.TOOL_DIR, "テスト・撮影は、遊んだログと別の場所に書く")


func test_game_events_are_recorded() -> void:
	_clean()
	var tree: SceneTree = t
	(tree.root.get_node("DataDB") as Node).call("reload")
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	tree.root.add_child(main)
	for i in 5:
		await tree.process_frame
	var game_log: GameLog = main.game_log
	t.check(game_log != null and FileAccess.file_exists(game_log.play_path), "メイン画面が記録を取り始める")
	var player := tree.get_first_node_in_group("player") as Player
	player.vitals.grant_xp(10000)
	var enemy: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy:
			enemy = n
			break
	enemy.take_hit(enemy.life + 1.0, DataDB.skill("slash"))
	player.use_skill(1, player.global_position + Vector2(50, 0))
	game_log.snapshot()
	t.check(game_log.kills >= 1, "撃破が数えられる")
	t.check(game_log.level > 1, "レベルアップが記録される")
	t.check(not game_log.skill_uses.is_empty(), "スキルの使用が数えられる")
	var play := _read(game_log.play_path)
	t.check(play.contains("level_up"), "レベルアップが、ファイルに書かれる")
	t.check(_read(game_log.debug_path).contains("snapshot"), "状態の記録が、デバッグのファイルに書かれる")
	main.queue_free()
