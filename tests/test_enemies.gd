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
	player.position = Vector2(-60, -30)
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


func _setup_ai() -> Array[Node2D]:
	var tree: SceneTree = t
	var manager := EnemyManager.new()
	tree.root.add_child(manager)
	manager.set_physics_process(false)
	var player := Node2D.new()
	tree.root.add_child(player)
	player.add_to_group("player")
	return [manager, player]


func test_idle_detection_chase_attack_and_recycle() -> void:
	var nodes: Array[Node2D] = _setup_ai()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var db: Node = (t as SceneTree).root.get_node("DataDB")
	var def: EnemyDef = db.enemy("swarmling")
	var enemy: Enemy = manager.spawn(def, Vector2.ZERO)
	var hits: Array = []
	manager.player_hit.connect(func(damage: float, source: Enemy) -> void: hits.append([damage, source]))
	player.position = Vector2(0, def.aggro_range * 0.5 + 1.0)
	manager._physics_process(1.0)
	t.check_eq(enemy.state, Enemy.State.IDLE, "地面距離で索敵範囲外なら待機")
	t.check_eq(enemy.position, Vector2.ZERO, "待機中は移動しない")
	player.position = Vector2(0, def.aggro_range * 0.5)
	manager._physics_process(0.1)
	t.check_eq(enemy.state, Enemy.State.CHASING, "索敵境界で追跡開始")
	t.check(enemy.position.y > 0.0, "追跡中だけ近づく")
	player.position = Vector2(1000, 0)
	manager._physics_process(0.1)
	t.check_eq(enemy.state, Enemy.State.CHASING, "索敵範囲を離れても追跡継続")
	player.position = enemy.position + Vector2(def.attack_range, 0)
	var before: Vector2 = enemy.position
	manager._physics_process(0.0)
	t.check_eq(enemy.state, Enemy.State.ATTACKING, "攻撃範囲で攻撃状態へ")
	manager._physics_process(def.attack_interval * 0.5 - 0.01)
	t.check_eq(hits.size(), 0, "初撃は半間隔まで待つ")
	manager._physics_process(0.01)
	t.check_eq(hits.size(), 1, "半間隔後に初撃")
	t.check_eq(hits[0], [def.damage, enemy], "ダメージと攻撃者を通知")
	t.check_eq(enemy.position, before, "攻撃中は止まる")
	manager._physics_process(def.attack_interval - 0.01)
	t.check_eq(hits.size(), 1, "次の攻撃は通常間隔まで待つ")
	manager._physics_process(0.01)
	t.check_eq(hits.size(), 2, "通常間隔ごとに攻撃")
	player.position = enemy.position + Vector2(0, def.attack_range)
	manager._physics_process(0.1)
	t.check_eq(enemy.state, Enemy.State.CHASING, "画面縦の距離も地面換算して射程外は追跡")
	t.check_eq(hits.size(), 2, "射程外では攻撃しない")
	manager.despawn(enemy)
	var reused: Enemy = manager.spawn(def, Vector2(-1000, -1000))
	t.check(reused == enemy, "AI個体も再利用")
	t.check_eq(reused.state, Enemy.State.IDLE, "再利用で待機に戻す")
	t.check_eq(reused.attack_timer, 0.0, "再利用で攻撃タイマーを消す")
	t.check_eq(reused.pack_id, -1, "単体生成に古い群れを持ち込まない")
	manager.queue_free()
	player.queue_free()
	await (t as SceneTree).process_frame


func test_pack_alert_placement_and_reuse_isolation() -> void:
	var nodes: Array[Node2D] = _setup_ai()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var def: EnemyDef = (t as SceneTree).root.get_node("DataDB").enemy("swarmling")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8008
	var pack: Array[Enemy] = manager.spawn_pack(def, Vector2(500, 100), rng)
	var other: Array[Enemy] = manager.spawn_pack(def, Vector2(2000, 100), rng)
	t.check(pack.size() >= def.pack_min and pack.size() <= def.pack_max, "群れの数は定義範囲内")
	var id: int = pack[0].pack_id
	for i: int in pack.size():
		t.check_eq(pack[i].pack_id, id, "群れ番号は共通")
		for j: int in range(i + 1, pack.size()):
			t.check(Iso.ground_distance(pack[i].position, pack[j].position) >= 11.99, "群れの初期配置は重ならない")
	pack[0].position = Vector2.ZERO
	player.position = Vector2(10, 0)
	manager._physics_process(0.0)
	for member: Enemy in pack:
		t.check(member.state != Enemy.State.IDLE, "遠くの仲間も同じフレームに反応")
	for member: Enemy in other:
		t.check_eq(member.state, Enemy.State.IDLE, "別の群れは反応しない")
	var recycled: Enemy = pack[1]
	manager.despawn(recycled)
	var single: Enemy = manager.spawn(def, Vector2(-2000, 100))
	t.check(single == recycled, "群れの個体を再利用")
	for member: Enemy in pack:
		if member != single:
			manager.despawn(member)
	t.check_eq(manager._packs.size(), 1, "空になった群れの登録を破棄")
	t.check_eq(single.state, Enemy.State.IDLE, "古い群れから独立")
	manager.queue_free()
	player.queue_free()
	await (t as SceneTree).process_frame


func test_tank_windup_and_dodge() -> void:
	var nodes: Array[Node2D] = _setup_ai()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var def: EnemyDef = (t as SceneTree).root.get_node("DataDB").enemy("brute")
	var enemy: Enemy = manager.spawn(def, Vector2(10, 0))
	var hits: Array[float] = []
	manager.player_hit.connect(func(damage: float, _source: Enemy) -> void: hits.append(damage))
	manager._physics_process(def.attack_interval * 0.5 - def.windup)
	t.check_eq(enemy.state, Enemy.State.WINDUP, "岩殻は初撃前にためる")
	t.check_eq(hits.size(), 0, "ため開始でダメージを出さない")
	manager._physics_process(def.windup - 0.01)
	t.check_eq(hits.size(), 0, "ためが終わるまで待つ")
	manager._physics_process(0.01)
	t.check_eq(hits.size(), 1, "ため終了で攻撃")
	manager._physics_process(def.attack_interval - def.windup)
	t.check_eq(enemy.state, Enemy.State.WINDUP, "通常間隔にもためを含める")
	player.position = Vector2(200, 0)
	var before: Vector2 = enemy.position
	# 重なる別個体がいてもため中の岩殻は動かない。
	var swarm_def: EnemyDef = (t as SceneTree).root.get_node("DataDB").enemy("swarmling")
	manager.spawn(swarm_def, enemy.position)
	manager._physics_process(def.windup)
	t.check_eq(hits.size(), 1, "ため中に離れれば回避できる")
	t.check_eq(enemy.state, Enemy.State.CHASING, "空振り後は追跡")
	# 空振りが確定する直前までは固定する。
	enemy.position = before
	enemy.state = Enemy.State.WINDUP
	enemy.attack_timer = 1.0
	manager._physics_process(0.1)
	t.check_eq(enemy.position, before, "ため中は押し合いでも動かない")
	manager.queue_free()
	player.queue_free()
	await (t as SceneTree).process_frame


func test_dummy_and_unsupported_behaviors_remain_idle() -> void:
	var nodes: Array[Node2D] = _setup_ai()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var hits: Array[float] = []
	manager.player_hit.connect(func(damage: float, _source: Enemy) -> void: hits.append(damage))
	for behavior: String in ["dummy", "ranged", "fast"]:
		var def := EnemyDef.new()
		def.behavior = behavior
		def.speed = 100.0
		def.aggro_range = 100.0
		def.attack_range = 100.0
		def.damage = 100.0
		var enemy: Enemy = manager.spawn(def, Vector2.ZERO)
		manager._physics_process(10.0)
		t.check_eq(enemy.state, Enemy.State.IDLE, "未実装と案山子は待機: " + behavior)
		t.check_eq(enemy.position, Vector2.ZERO, "重なっても動かない: " + behavior)
	t.check_eq(hits.size(), 0, "未実装と案山子は攻撃しない")
	manager.queue_free()
	player.queue_free()
	await (t as SceneTree).process_frame


func test_enemy_ai_data_defaults_and_validation() -> void:
	var errors: Array[String] = []
	var def: EnemyDef = EnemyDef.from_dict({"id": "test", "behavior": "tank", "life": 1}, errors)
	t.check_eq(def.windup, 0.0, "windup省略時は0")
	t.check_eq(errors.size(), 0, "既存データ互換")
	EnemyDef.from_dict({"id": "bad", "behavior": "tank", "life": 1, "aggro_range": -1, "windup": -1, "pack": [0, 2]}, errors)
	t.check_eq(errors.size(), 2, "負の索敵・ためと空の群れを拒否")
