extends RefCounted

var t: Variant


func test_150_enemies_move_and_recycle() -> void:
	var tree: SceneTree = t
	# run_tests の初期化直後にも DataDB を待てるようにする。
	await tree.process_frame
	var db: Node = tree.root.get_node("DataDB")
	var def: EnemyDef = db.enemy("swarmling")
	var manager := EnemyManager.new()
	tree.root.add_child(manager)
	var player := Node2D.new()
	player.position = Vector2(-100, -50)
	player.add_to_group("player")
	tree.root.add_child(player)
	var first: Enemy
	for i: int in 150:
		var enemy: Enemy = manager.spawn(def, Vector2((i % 15) * 16, (i / 15) * 8))
		if i == 0:
			first = enemy
	var before: Vector2 = first.global_position
	for i: int in 10:
		await tree.physics_frame
	t.check_eq(manager.active_count(), 150, "150体が稼働")
	t.check_eq(tree.get_nodes_in_group("enemies").size(), 150, "当たり判定グループに150体")
	t.check(Iso.ground_distance(first.global_position, player.position) < Iso.ground_distance(before, player.position), "プレイヤーに向かう")
	for enemy: Node in manager.get_children():
		t.check((enemy as Enemy).position.is_finite(), "位置が有限")
	t.check(manager.last_pair_checks < 150 * 149 / 2, "近傍だけ比較する")
	first.take_hit(def.life / 2.0, null)
	t.check_eq(first.life, def.life / 2.0, "非致死ダメージ")
	first.take_hit(def.life, null)
	t.check_eq(manager.active_count(), 149, "撃破で稼働数が減る")
	t.check_eq(manager.pooled_count(), 1, "撃破でプールに戻る")
	t.check(not first.visible and not first.is_in_group("enemies"), "プール中は描画と攻撃対象から外す")
	first.take_hit(def.life, null)
	manager.despawn(first)
	t.check_eq(manager.pooled_count(), 1, "二重返却しない")
	var reused: Enemy = manager.spawn(db.enemy("brute"), Vector2(300, -30))
	t.check(reused == first, "同じ個体を再利用する")
	t.check_eq(reused.life, reused.definition.life, "再利用時に新しい定義のライフへ戻す")
	t.check_eq(reused.global_position, Vector2(300, -30), "再利用時に位置を設定")
	t.check(reused.visible and reused.is_in_group("enemies"), "再利用で描画と攻撃対象を戻す")
	t.check_eq(manager.get_child_count(), 150, "ノードが増殖しない")
	manager.queue_free()
	player.queue_free()
	await tree.process_frame


func test_separation_at_same_position_and_cell_boundary() -> void:
	var tree: SceneTree = t
	var db: Node = tree.root.get_node("DataDB")
	var manager := EnemyManager.new()
	manager.position = Vector2(70, 30)
	tree.root.add_child(manager)
	manager.set_physics_process(false)
	var a: Enemy = manager.spawn(db.enemy("swarmling"), Vector2(-12.1, -6.1))
	var b: Enemy = manager.spawn(db.enemy("swarmling"), a.global_position)
	manager._physics_process(0.0)
	t.check(Iso.ground_distance(a.global_position, b.global_position) >= a.hit_radius + b.hit_radius - 0.001, "完全一致でも押し分ける")
	a.global_position = Vector2(-0.1, -0.1)
	b.global_position = Vector2(0.1, 0.1)
	manager._physics_process(0.0)
	t.check(Iso.ground_distance(a.global_position, b.global_position) >= a.hit_radius + b.hit_radius - 0.001, "負座標とセル境界をまたいで押し分ける")
	manager.queue_free()
	await tree.process_frame
