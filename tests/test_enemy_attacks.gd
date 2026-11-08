extends RefCounted
## 敵の攻撃の種類：遠距離（毒吐きスライム）の弾、岩殻・ボスの突進と扇形の弾、攻撃のエフェクト

var t: Variant


func _setup() -> Array[Node2D]:
	var tree: SceneTree = t
	(tree.root.get_node("DataDB") as Node).call("reload")
	var manager := EnemyManager.new()
	tree.root.add_child(manager)
	manager.set_physics_process(false)
	var player := Node2D.new()
	tree.root.add_child(player)
	player.add_to_group("player")
	return [manager, player]


func _def(id: String) -> EnemyDef:
	return (t as SceneTree).root.get_node("DataDB").enemy(id)


func _cleanup(manager: Node, player: Node) -> void:
	manager.queue_free()
	player.queue_free()
	await (t as SceneTree).process_frame


func test_spitter_data() -> void:
	var def: EnemyDef = _def("spitter")
	t.check(def != null, "毒吐きスライムの定義がある")
	if def == null:
		return
	t.check_eq(def.behavior, "ranged", "遠距離の動き")
	t.check(def.shot_damage > 0.0 and def.shot_range > 0.0, "弾を撃つ")
	t.check(def.color != _def("swarmling").color, "ふつうのスライムと色が違う")
	t.check(def.attack_range > 60.0, "離れたところから撃つ")


func test_spitter_shoots_and_keeps_distance() -> void:
	var nodes: Array[Node2D] = _setup()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var def: EnemyDef = _def("spitter")
	var enemy: Enemy = manager.spawn(def, Vector2.ZERO)
	var charged: Array[int] = [0]
	var fired: Array[int] = [0]
	manager.shot_charging.connect(func(_e: Enemy, _w: float) -> void: charged[0] += 1)
	manager.shot_fired.connect(func(_e: Enemy) -> void: fired[0] += 1)
	var hits: Array[float] = []
	manager.player_hit.connect(func(damage: float, _source: Enemy) -> void: hits.append(damage))
	player.position = Vector2(0, def.aggro_range * 0.5 - 5.0)  # 地面の距離で、索敵の中・射程の内
	manager._physics_process(0.01)
	t.check_eq(enemy.state, Enemy.State.CHASING, "近づくと動き出す")
	for i: int in 400:
		manager._physics_process(0.02)
		if fired[0] > 0:
			break
	t.check(charged[0] >= 1, "撃つ前に、ためる")
	t.check(fired[0] >= 1, "弾を撃つ")
	t.check(manager.bullet_count() >= 1, "弾が飛んでいる")
	# 近づかれると下がる
	var near: Vector2 = Vector2(0, 8.0)
	player.position = enemy.position + near
	var before: float = Iso.ground_distance(enemy.position, player.position)
	enemy.shot_timer = 100.0
	enemy.shot_windup_left = 0.0
	for i: int in 20:
		manager._physics_process(0.05)
	t.check(Iso.ground_distance(enemy.position, player.position) > before, "近づかれたら、下がる")
	await _cleanup(manager, player)


func test_bullet_hits_player_and_flies_out() -> void:
	var nodes: Array[Node2D] = _setup()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var def: EnemyDef = _def("spitter")
	var enemy: Enemy = manager.spawn(def, Vector2.ZERO)
	enemy.state = Enemy.State.CHASING
	enemy.shot_timer = 1000.0  # 自分では撃たせない（試験で出した弾だけを見る）
	var hits: Array[float] = []
	var landed: Array[int] = [0]
	manager.player_hit.connect(func(damage: float, _source: Enemy) -> void: hits.append(damage))
	manager.bullet_landed.connect(func(_p: Vector2, _c: Color) -> void: landed[0] += 1)
	player.position = Vector2(60, 0)
	manager._fire(enemy, player.position)
	t.check_eq(manager.bullet_count(), 1, "1発出る")
	for i: int in 100:
		manager._physics_process(0.02)
	t.check_eq(hits.size(), 1, "当たったら、ダメージが1回入る")
	t.check_eq(hits[0] if hits.size() > 0 else 0.0, def.shot_damage, "弾のダメージ")
	t.check_eq(manager.bullet_count(), 0, "当たった弾は消える")
	t.check(landed[0] >= 1, "当たった場所に、エフェクトの信号が出る")
	# 外れた弾は、飛びきったら消える
	player.position = Vector2(0, 1000)
	manager._fire(enemy, Vector2(60, 0))
	for i: int in 200:
		manager._physics_process(0.02)
	t.check_eq(manager.bullet_count(), 0, "飛びきった弾は消える")
	t.check_eq(hits.size(), 1, "外れた弾はダメージを出さない")
	await _cleanup(manager, player)


func test_bullet_stops_at_wall() -> void:
	var nodes: Array[Node2D] = _setup()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	manager.blocked = func(pos: Vector2) -> bool: return pos.x > 20.0  # x が20より先は壁
	var enemy: Enemy = manager.spawn(_def("spitter"), Vector2.ZERO)
	enemy.state = Enemy.State.CHASING
	var hits: Array[float] = []
	manager.player_hit.connect(func(damage: float, _source: Enemy) -> void: hits.append(damage))
	player.position = Vector2(60, 0)
	manager._fire(enemy, player.position)
	for i: int in 100:
		manager._physics_process(0.02)
	t.check_eq(hits.size(), 0, "壁の向こうのプレイヤーには、弾が届かない")
	t.check_eq(manager.bullet_count(), 0, "壁にぶつかった弾は消える")
	await _cleanup(manager, player)


func test_boss_and_brute_have_more_attacks() -> void:
	var brute: EnemyDef = _def("brute")
	var boss: EnemyDef = _def("rock_lord")
	t.check(brute.charge_damage > 0.0 and brute.aoe_radius > 0.0, "中ボスは、突進と叩きつけがある")
	t.check(boss.charge_damage > 0.0, "ボスは突進がある")
	t.check(boss.shot_damage > 0.0 and boss.shot_count >= 3, "ボスは扇形の弾がある")
	t.check(boss.aoe_radius > 0.0 and boss.rain_radius > 0.0, "ボスの範囲攻撃と岩落としは残っている")


func test_charge_telegraph_then_dash_hits_once() -> void:
	var nodes: Array[Node2D] = _setup()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var def: EnemyDef = _def("rock_lord")
	var enemy: Enemy = manager.spawn(def, Vector2.ZERO)
	enemy.state = Enemy.State.CHASING
	enemy.aoe_timer = 1000.0  # 範囲攻撃・弾は止めて、突進だけを見る
	enemy.shot_timer = 1000.0
	enemy.charge_timer = 0.0
	player.position = Vector2(60, 0)
	var seen: Array[int] = [0, 0, 0]
	manager.charge_telegraph.connect(func(_e: Enemy, _d: Vector2, _l: float, _w: float, _wu: float) -> void: seen[0] += 1)
	manager.charge_started.connect(func(_e: Enemy) -> void: seen[1] += 1)
	manager.charge_ended.connect(func(_e: Enemy) -> void: seen[2] += 1)
	var hits: Array[float] = []
	manager.player_hit.connect(func(damage: float, _source: Enemy) -> void: hits.append(damage))
	manager._physics_process(0.02)
	t.check_eq(enemy.charge_phase, 1, "まず予告")
	t.check_eq(seen[0], 1, "予告の信号が出る")
	var start: Vector2 = enemy.position
	manager._physics_process(def.charge_windup * 0.5)
	t.check_eq(enemy.position, start, "予告のあいだは動かない")
	t.check_eq(hits.size(), 0, "予告のあいだはダメージなし")
	manager._physics_process(def.charge_windup)
	t.check_eq(enemy.charge_phase, 2, "予告のあと突進が始まる")
	for i: int in 100:
		manager._physics_process(0.02)
	t.check_eq(seen[1], 1, "突進の開始の信号")
	t.check_eq(seen[2], 1, "突進の終わりの信号")
	t.check_eq(enemy.charge_phase, 0, "突進が終わる")
	t.check_eq(hits.size(), 1, "通り道のプレイヤーに、1回だけ当たる")
	t.check_eq(hits[0] if hits.size() > 0 else 0.0, def.charge_damage, "突進のダメージ")
	t.check(enemy.position.x > start.x + 20.0, "向かった方向へ進んだ")
	await _cleanup(manager, player)


func test_charge_can_be_dodged_by_leaving_the_lane() -> void:
	var nodes: Array[Node2D] = _setup()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var def: EnemyDef = _def("brute")
	var enemy: Enemy = manager.spawn(def, Vector2.ZERO)
	enemy.state = Enemy.State.CHASING
	enemy.aoe_timer = 1000.0
	enemy.charge_timer = 0.0
	player.position = Vector2(60, 0)
	var hits: Array[float] = []
	manager.player_hit.connect(func(damage: float, _source: Enemy) -> void: hits.append(damage))
	manager._physics_process(0.02)  # 予告で向きが決まる
	player.position = Vector2(60, 60)  # 帯から外れる
	for i: int in 100:
		manager._physics_process(0.02)
	t.check_eq(hits.size(), 0, "帯から外れれば、突進は当たらない")
	await _cleanup(manager, player)


func test_charge_stops_at_wall() -> void:
	var nodes: Array[Node2D] = _setup()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	manager.blocked = func(pos: Vector2) -> bool: return pos.x > 30.0
	var def: EnemyDef = _def("rock_lord")
	var enemy: Enemy = manager.spawn(def, Vector2.ZERO)
	enemy.state = Enemy.State.CHASING
	enemy.aoe_timer = 1000.0
	enemy.shot_timer = 1000.0
	enemy.charge_timer = 0.0
	player.position = Vector2(80, 0)
	manager._physics_process(0.02)
	manager._physics_process(def.charge_windup + 0.05)
	for i: int in 100:
		manager._physics_process(0.02)
		if enemy.charge_phase == 0:
			break
	t.check(enemy.position.x <= 30.0 + 1.0, "壁の手前で止まる")
	t.check_eq(enemy.charge_phase, 0, "止まったら突進は終わり")
	await _cleanup(manager, player)


func test_boss_fan_shot() -> void:
	var nodes: Array[Node2D] = _setup()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var def: EnemyDef = _def("rock_lord")
	var enemy: Enemy = manager.spawn(def, Vector2.ZERO)
	enemy.state = Enemy.State.CHASING
	enemy.aoe_timer = 1000.0
	enemy.charge_timer = 1000.0
	enemy.shot_timer = 0.0
	player.position = Vector2(100, 0)
	manager._physics_process(0.02)
	t.check(enemy.shot_windup_left > 0.0, "ボスは、撃つ前にためる（足を止める）")
	manager._physics_process(def.shot_windup + 0.05)
	t.check_eq(manager.bullet_count(), def.shot_count, "扇形に、決まった数が出る")
	await _cleanup(manager, player)


func test_enemy_attack_fx() -> void:
	var tree: SceneTree = t
	var nodes: Array[Node2D] = _setup()
	var manager: EnemyManager = nodes[0]
	var player_node := Player.new()
	tree.root.add_child(player_node)
	var holder := Node2D.new()
	tree.root.add_child(holder)
	var director := EnemyFxDirector.new()
	tree.root.add_child(director)
	director.setup(manager, player_node, holder)
	var enemy: Enemy = manager.spawn(_def("rock_lord"), Vector2.ZERO)
	var before: int = holder.get_child_count()
	player_node.on_player_hit(5.0, enemy)
	t.check(holder.get_child_count() > before, "殴られると、エフェクトが出る")
	before = holder.get_child_count()
	manager.aoe_burst.emit(enemy, 80.0)
	t.check(holder.get_child_count() > before, "範囲攻撃が当たると、衝撃の輪が出る")
	before = holder.get_child_count()
	manager.rain_impact.emit(Vector2(10, 10), 40.0)
	t.check(holder.get_child_count() > before, "岩が落ちると、エフェクトが出る")
	before = holder.get_child_count()
	manager.shot_fired.emit(enemy)
	manager.bullet_landed.emit(Vector2.ZERO, Color.WHITE)
	t.check(holder.get_child_count() >= before + 2, "撃つ・当たるで、エフェクトが出る")
	# 回避中は殴られないので、エフェクトも出ない
	player_node.start_dodge(Vector2.RIGHT)
	before = holder.get_child_count()
	player_node.on_player_hit(5.0, enemy)
	t.check_eq(holder.get_child_count(), before, "回避中は、殴られたエフェクトは出ない")
	# エフェクトは、時間がたてば消える
	for child: Node in holder.get_children():
		if child is EnemyFx:
			(child as EnemyFx)._process(5.0)
	await tree.process_frame
	await tree.process_frame
	t.check_eq(holder.get_child_count(), 0, "エフェクトは消える")
	director.queue_free()
	holder.queue_free()
	player_node.queue_free()
	await _cleanup(manager, nodes[1])


func test_field_has_spitter_markers() -> void:
	var main_script: GDScript = load("res://scripts/main/main.gd")
	var rows: PackedStringArray = main_script.load_map(main_script.MAP_PATH)
	var count: int = 0
	for row: String in rows:
		count += row.count("r")
	t.check(count >= 4, "マップに、遠距離スライムの印がある")


func test_attacks_do_not_interrupt_each_other() -> void:
	var nodes: Array[Node2D] = _setup()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var def: EnemyDef = _def("rock_lord")
	var enemy: Enemy = manager.spawn(def, Vector2.ZERO)
	enemy.state = Enemy.State.CHASING
	player.position = Vector2(60, 0)
	enemy.charge_timer = 0.0
	enemy.aoe_timer = 0.0  # 突進と叩きつけが同時に始まりたがる
	enemy.shot_timer = 0.0
	manager._physics_process(0.02)
	var started: int = int(enemy.charge_phase != 0) + int(enemy.aoe_windup_left > 0.0) + int(enemy.shot_windup_left > 0.0)
	t.check_eq(started, 1, "攻撃は、同時に1つしか始まらない")
	# 突進の予告のあいだは、叩きつけのタイマーが割り込まない
	if enemy.charge_phase == 1:
		var aoe_before: float = enemy.aoe_timer
		manager._physics_process(def.charge_windup * 0.5)
		t.check_eq(enemy.aoe_timer, aoe_before, "突進の予告中は、ほかの攻撃のタイマーが進まない")
		t.check_eq(enemy.aoe_windup_left, 0.0, "突進の予告中に、叩きつけが始まらない")
	await _cleanup(manager, player)


func test_boss_aoe_is_wider_when_raged() -> void:
	var nodes: Array[Node2D] = _setup()
	var manager: EnemyManager = nodes[0]
	var player: Node2D = nodes[1]
	var def: EnemyDef = _def("rock_lord")
	t.check_eq(def.rage_aoe_mult, 1.5, "激昂中の範囲は1.5倍")
	var enemy: Enemy = manager.spawn(def, Vector2.ZERO)
	enemy.state = Enemy.State.CHASING
	var radii: Array[float] = []
	manager.aoe_telegraph.connect(func(_e: Enemy, radius: float, _w: float) -> void: radii.append(radius))
	enemy.charge_timer = 1000.0
	enemy.shot_timer = 1000.0
	player.position = Vector2(0, 500)
	enemy.aoe_timer = 0.0
	manager._physics_process(0.01)
	t.check_eq(radii[0] if radii.size() > 0 else 0.0, def.aoe_radius, "ふだんの範囲")
	enemy.aoe_windup_left = 0.0
	enemy.raged = true
	enemy.aoe_timer = 0.0
	manager._physics_process(0.01)
	t.check_eq(radii[1] if radii.size() > 1 else 0.0, def.aoe_radius * 1.5, "激昂中は1.5倍")
	# 当たりも広い：ふだんの半径の外・1.5倍の内にいたら、激昂中は当たる
	var hits: Array[float] = []
	manager.player_hit.connect(func(damage: float, _source: Enemy) -> void: hits.append(damage))
	player.position = Vector2(def.aoe_radius * 1.3, 0)
	manager._physics_process(def.aoe_windup + 0.05)
	t.check_eq(hits.size(), 1, "広がった範囲の中なら、当たる")
	await _cleanup(manager, player)
