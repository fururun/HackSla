extends RefCounted
## 画面を2つ重ねて開閉しても、止まったまま戻らなくならない

var t: Variant


func _screens() -> Array:
	var tree: SceneTree = t
	PauseHolder.reset()
	tree.paused = false
	var skill := SkillScreen.new()
	var equip := EquipScreen.new()
	tree.root.add_child(skill)
	tree.root.add_child(equip)
	return [skill, equip]


func _cleanup(screens: Array) -> void:
	for s: Node in screens:
		s.queue_free()
	PauseHolder.reset()
	(t as SceneTree).paused = false


func test_two_screens_opened_and_closed_in_any_order_never_stay_paused() -> void:
	var tree: SceneTree = t
	# K → I → K を閉じる → I を閉じる（以前は、止まったまま戻らなかった順番）
	var s := _screens()
	var skill: SkillScreen = s[0]
	var equip: EquipScreen = s[1]
	skill.open()
	t.check(tree.paused, "1つ開くと止まる")
	equip.open()
	skill.close()
	t.check(tree.paused, "もう1つ開いているあいだは、止まったまま")
	equip.close()
	t.check(not tree.paused, "全部閉じたら、動く")
	# 逆の順番
	equip.open()
	skill.open()
	equip.close()
	t.check(tree.paused, "逆順でも、1つ開いているあいだは止まる")
	skill.close()
	t.check(not tree.paused, "逆順でも、全部閉じたら動く")
	t.check_eq(PauseHolder.count(), 0, "開いている画面の数が 0 に戻る")
	_cleanup(s)


func test_freeing_an_open_screen_releases_the_pause() -> void:
	var tree: SceneTree = t
	var s := _screens()
	var skill: SkillScreen = s[0]
	skill.open()
	t.check(tree.paused, "開くと止まる")
	skill.close()
	skill.close()  # 二重に閉じても、壊れない
	t.check(not tree.paused, "動く")
	_cleanup(s)


func test_hitstop_is_restored_by_deadline_even_without_the_timer() -> void:
	var tree: SceneTree = t
	Engine.time_scale = 1.0
	HitFeedback._next_stop_usec = 0  # 直前の試験の撃破で、停止の休み時間に入っていても、影響を受けない
	HitFeedback._stop_owner = null
	var fb := HitFeedback.new()
	tree.root.add_child(fb)
	fb.request_hitstop()
	t.check(Engine.time_scale < 1.0, "ヒットストップで遅くなる")
	# タイマーが届かなかった状況：終わりの時刻を過去にして、1フレーム処理させる
	fb._stop_end_usec = Time.get_ticks_usec() - 1
	fb._process(0.016)
	t.check_eq(Engine.time_scale, 1.0, "時刻を過ぎたら、必ず元に戻る")
	fb.queue_free()
	Engine.time_scale = 1.0
