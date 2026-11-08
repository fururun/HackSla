class_name RestartListener
extends Node
## F5 でゲームを最初からやり直す。スキル装備画面で止まっている間も効くよう、常に動くノードにする。


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_game"):
		restart()


func restart() -> void:
	var tree := get_tree()
	PauseHolder.reset()  # 開いている画面の数え直し（シーンを作り直すので）
	tree.paused = false
	Engine.time_scale = 1.0  # ヒットストップ中に押しても、時間が遅いまま残らないように戻す
	tree.reload_current_scene()
