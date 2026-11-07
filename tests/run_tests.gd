extends SceneTree
## テストの実行：godot --headless --script res://tests/run_tests.gd
## 失敗があれば終了コード 1。新しいテストは tests/test_*.gd に test_ で始まる関数を書くだけで追加される。

var _failed: int = 0
var _passed: int = 0
var _current: String = ""


func _initialize() -> void:
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for f: String in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f: String in files:
		var script: GDScript = load("res://tests/" + f)
		var suite: Object = script.new()
		suite.set("t", self)
		for m: Dictionary in script.get_script_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_"):
				_current = "%s :: %s" % [f, mname]
				await suite.call(mname)
		if suite is Node:
			(suite as Node).queue_free()
	print("")
	print("== テスト結果: 成功 %d / 失敗 %d ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("  ✗ %s — %s" % [_current, msg])


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	check(a == b, "%s（実際: %s / 期待: %s）" % [msg, str(a), str(b)])
