class_name RestartListener
extends Node
## リスタート。F5＝リセット（完全にやり直す）、F9＝引き継いでリスタート（レベル・ツリー・装備を持ち越す。RunCarry）。
## スキル装備画面で止まっている間も効くよう、常に動くノードにする。


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_game"):
		restart(RunCarry.Mode.RESET)
	elif event.is_action_pressed("restart_carry"):
		restart(RunCarry.Mode.CARRY)
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed and _player_dead():
		# コントローラー：やられたとき、A＝引き継いでリスタート、B＝リセット
		var button: int = (event as InputEventJoypadButton).button_index
		if button == JOY_BUTTON_A:
			restart(RunCarry.Mode.CARRY)
		elif button == JOY_BUTTON_B:
			restart(RunCarry.Mode.RESET)


func _player_dead() -> bool:
	var parent: Node = get_parent()
	var player: Variant = parent.get("player") if parent != null else null
	return player is Player and (player as Player).vitals.is_dead()


func restart(mode: RunCarry.Mode = RunCarry.Mode.RESET) -> void:
	var tree := get_tree()
	var parent: Node = get_parent()
	var vitals: PlayerVitals = null
	var player: Variant = parent.get("player") if parent != null else null
	if player is Player:
		vitals = (player as Player).vitals
	var stash: Variant = parent.get("stash") if parent != null else null
	var skill_tree: Variant = parent.get("skill_tree") if parent != null else null
	var recorder: Variant = get_parent().get("balance_log") if get_parent() != null else null
	if recorder is BalanceLog:
		(recorder as BalanceLog).finish_for_restart()  # やり直す前に、このプレイの記録を書く
	var pilot: Variant = get_parent().get("autopilot") if get_parent() != null else null
	if pilot is Autopilot:
		(pilot as Autopilot).save_state()  # 自動戦闘が入っていれば、やり直したあとも続ける
	RunCarry.prepare(mode, vitals, stash if stash is Stash else null, skill_tree if skill_tree is SkillTree else null, (player as Player).caster.loadout if player is Player else null)
	PauseHolder.reset()  # 開いている画面の数え直し（シーンを作り直すので）
	tree.paused = false
	Engine.time_scale = 1.0  # ヒットストップ中に押しても、時間が遅いまま残らないように戻す
	tree.reload_current_scene()
