extends RefCounted

var t: Variant


func test_hit_signal_and_kill_count() -> void:
	var tree: SceneTree = t
	await tree.process_frame
	var manager := EnemyManager.new()
	tree.root.add_child(manager)
	manager.set_physics_process(false)
	var def := EnemyDef.new()
	def.life = 30.0
	var enemy: Enemy = manager.spawn(def, Vector2(50, 30))
	var feedback: HitFeedback = manager._feedback
	manager.spawn(def, Vector2.ZERO)
	t.check_eq(manager._feedback, feedback, "初回生成だけで演出を作る")
	var hits: Array = []
	manager.enemy_hit.connect(func(source: Enemy, amount: float, killed: bool) -> void: hits.append([source, amount, killed, source.active]))
	enemy.take_hit(0.0, null)
	enemy.take_hit(-5.0, null)
	enemy.take_hit(NAN, null)
	t.check_eq(hits.size(), 0, "無効ダメージは通知しない")
	enemy.take_hit(10.0, null)
	t.check_eq(hits[0], [enemy, 10.0, false, true], "実際のダメージと非撃破を通知")
	t.check_eq(feedback.kill_count, 0, "被弾だけでは撃破を加算しない")
	enemy.take_hit(100.0, null)
	t.check_eq(hits[1], [enemy, 20.0, true, true], "位置が有効な返却前に致死ダメージを通知")
	enemy.take_hit(100.0, null)
	t.check_eq(hits.size(), 2, "返却済みの敵は通知しない")
	t.check_eq(feedback.kill_count, 1, "撃破を一度だけ加算")
	var dummy_def: EnemyDef = tree.root.get_node("DataDB").enemy("training_dummy")
	var dummy: Enemy = manager.spawn(dummy_def, Vector2.ZERO)
	dummy.take_hit(100.0, null)
	t.check_eq(hits.size(), 2, "不死の案山子では発信しない")
	t.check_eq(dummy.life, dummy_def.life, "案山子のライフは減らない")
	manager.free()


func test_number_pool_limit_oldest_and_expired_reuse() -> void:
	var tree: SceneTree = t
	var parent := Node2D.new()
	parent.position = Vector2(100, 50)
	tree.root.add_child(parent)
	var first: DamageNumber = DamageNumber.spawn(parent, Vector2(20, 30), 12.0)
	t.check_eq(first.global_position.y, 30.0, "変形した親でも世界座標へ表示")
	for i: int in range(1, FeedbackConfig.NUMBER_LIMIT):
		DamageNumber.spawn(parent, Vector2.ZERO, float(i))
	var reused: DamageNumber = DamageNumber.spawn(parent, Vector2(10, 20), 99.0)
	t.check_eq(reused, first, "上限時は最古の数字を再利用")
	t.check_eq(reused.text, "99", "再利用時に数字を更新")
	for i: int in 150:
		DamageNumber.spawn(parent, Vector2.ZERO, float(i))
	t.check_eq(parent.get_meta(DamageNumber.POOL_META).size(), FeedbackConfig.NUMBER_LIMIT, "大量被弾でも上限を維持")
	t.check_eq(parent.get_child_count(true), FeedbackConfig.NUMBER_LIMIT, "ノード数も上限内")
	reused._process(FeedbackConfig.NUMBER_LIFE)
	t.check(not reused.active and not reused.visible, "寿命後は破棄せず非表示")
	var expired: DamageNumber = DamageNumber.spawn(parent, Vector2(30, 40), 42.0)
	t.check_eq(expired, reused, "空いている数字を優先して再利用")
	t.check(expired.active and expired.visible and expired.modulate.a == 1.0, "寿命・透明度をリセット")
	parent.free()


func test_hitstop_burst_bound_restore_and_camera() -> void:
	var tree: SceneTree = t
	await tree.create_timer(FeedbackConfig.HITSTOP_MAX_SECONDS + FeedbackConfig.HITSTOP_RECOVERY_SECONDS, true, false, true).timeout
	var original_scale: float = Engine.time_scale
	Engine.time_scale = 0.8
	var manager := EnemyManager.new()
	tree.root.add_child(manager)
	manager.set_physics_process(false)
	var camera := Camera2D.new()
	camera.offset = Vector2(7, -10)
	tree.root.add_child(camera)
	camera.make_current()
	var def := EnemyDef.new()
	def.life = 30.0
	var enemies: Array[Enemy] = []
	for i: int in 150:
		enemies.append(manager.spawn(def, Vector2(i, 20)))
	var feedback: HitFeedback = manager._feedback
	var start: int = Time.get_ticks_usec()
	for enemy: Enemy in enemies:
		enemy.take_hit(100.0, null)
	print("[fx burst] 150 kills dispatch_ms=%.3f number_nodes=%d" % [float(Time.get_ticks_usec() - start) / 1000.0, feedback.get_meta(DamageNumber.POOL_META).size()])
	feedback._process(0.0)
	t.check(feedback._counter.get_global_rect().end.x <= tree.root.get_visible_rect().end.x, "拡大中も撃破表示は画面内")
	var timer: SceneTreeTimer = feedback._stop_timer
	t.check(timer != null and timer.time_left <= FeedbackConfig.HITSTOP_MAX_SECONDS, "停止時間は合計上限内")
	for i: int in 200:
		feedback.request_hitstop()
	t.check_eq(feedback._stop_timer, timer, "同時撃破は同じタイマーを共有し延長しない")
	t.check_eq(feedback.kill_count, 150, "一斉撃破を全て加算")
	t.check_eq(feedback._counter.text, "撃破 150", "撃破表示を更新")
	t.check_eq(Engine.time_scale, FeedbackConfig.HITSTOP_SCALE, "撃破で減速")
	await tree.create_timer(FeedbackConfig.HITSTOP_MAX_SECONDS, true, false, true).timeout
	t.check_eq(Engine.time_scale, 0.8, "実時間の上限後に元の倍率へ復元")
	feedback.request_hitstop()
	t.check_eq(Engine.time_scale, 0.8, "回復期間中は再停止しない")
	await tree.create_timer(FeedbackConfig.SHAKE_SECONDS + FeedbackConfig.COUNTER_PULSE_SECONDS, true, false, true).timeout
	t.check_eq(camera.offset, Vector2(7, -10), "揺れ後に元のカメラoffsetへ復元")
	t.check_eq(feedback._counter.scale, Vector2.ONE, "撃破数の拡大が戻る")
	feedback.request_hitstop()
	t.check(Engine.time_scale < 0.8, "回復期間後は再受付")
	manager.free()
	t.check_eq(Engine.time_scale, 0.8, "停止中のシーン破棄でも倍率を復元")
	camera.free()
	Engine.time_scale = original_scale
