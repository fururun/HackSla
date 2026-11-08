extends RefCounted
## メイン画面でつないだ流れ：敵に殴られる → 倒すと経験値とドロップ → 拾うと装備がステータスに効く

var t: Variant


func _start_main() -> Node:
	var tree: SceneTree = t
	# 他のテストがデータを入れ替えることがあるので、メイン画面を作る前に読み込み直す
	(tree.root.get_node("DataDB") as Node).call("reload")
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	tree.root.add_child(main)
	for i in 5:
		await tree.process_frame
	return main


func test_skills_aim_where_the_character_faces() -> void:
	var main: Node = await _start_main()
	var player := (t as SceneTree).get_first_node_in_group("player") as Player
	player.global_position = Vector2(100000, 100000)  # 敵がいない遠くへ
	for index: int in 8:
		player.facing = index
		var dir := player.aim_target() - player.global_position
		t.check_eq(Facing.dir8(dir), index, "敵がいなければ、向き %d の方向に狙いが出る" % index)
	player.facing = 6  # 上向き
	t.check(player.aim_target().y < player.global_position.y, "上向きなら上に狙う")
	player.facing = 0  # 右向き
	t.check(player.aim_target().x > player.global_position.x and is_equal_approx(player.aim_target().y, player.global_position.y), "右向きなら真横に狙う")
	main.queue_free()


func test_boss_is_placed_big_and_bar_follows_its_life() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var boss: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy and n.definition.is_boss:
			boss = n
	t.check(boss != null, "マップの印 X にボスがいる")
	if boss == null:
		main.queue_free()
		return
	t.check(boss.definition.scale > 1.5, "ボスは大きい")
	t.check(boss.hit_radius > Enemy.TANK_HIT_RADIUS, "ボスは押し合いの半径も大きい")
	t.check(boss.definition.life > 5 * DataDB.enemy("brute").life, "ボスは岩殻よりずっと硬い")
	var bar: BossBar = null
	for child: Node in main.get_children():
		if child is BossBar:
			bar = child
	t.check(not boss.life_bar_visible(), "ボスが待機のあいだは、頭の上の棒を出さない")
	boss.state = Enemy.State.CHASING
	t.check(boss.life_bar_visible(), "ボスが動き出したら、頭の上に棒を出す")
	t.check(is_equal_approx(boss.life_ratio(), 1.0), "最初は満タン")
	boss.take_hit(boss.definition.life * 0.5, DataDB.skill("slash"))
	t.check(absf(boss.life_ratio() - 0.5) < 0.02, "体力が半分になると、棒も半分")
	# 中ボス（岩殻）も、傷つくと頭の上に棒が出る。スライムには出ない
	var brute: Enemy = null
	var slime: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy and not n.definition.is_boss and n.active:
			if n.definition.behavior == "tank" and brute == null:
				brute = n
			elif n.definition.behavior != "tank" and slime == null:
				slime = n
	if brute != null:
		t.check(not brute.life_bar_visible(), "中ボスも、待機中は棒を出さない")
		brute.take_hit(10.0, DataDB.skill("slash"))
		t.check(brute.life_bar_visible(), "中ボスは、傷つくと頭の上に棒が出る")
	if slime != null:
		slime.take_hit(1.0, DataDB.skill("slash"))
		t.check(not slime.life_bar_visible(), "スライムには棒を出さない")
	if bar != null:
		boss.take_hit(boss.life + 1.0, DataDB.skill("slash"))
		t.check(bar.is_victory_showing(), "倒したら、撃破の文字が出る")
	main.queue_free()


func test_ui_does_not_cover_the_screen() -> void:
	var main: Node = await _start_main()
	# 操作ヘルプは、最初は開き、H で小さな一言と切り替わる
	t.check(main._help_open and main._help_label.text.contains("WASD"), "最初は、操作ヘルプが開いている")
	main.set_help_open(false)
	t.check(main._help_label.text == main.HELP_COMPACT and main._help_label.modulate.a < 1.0, "閉じると、小さくうすい一言になる")
	main.set_help_open(true)
	t.check(main._help_label.text.contains("WASD"), "H でまた開ける")
	# 通知がないあいだは、右上に枠が出ない
	var loot_hud: LootHud = null
	for child: Node in main.get_children():
		if child is LootHud:
			loot_hud = child
	t.check(loot_hud != null and not loot_hud._panel.visible, "拾ったものの通知がないあいだは、枠が出ない")
	# 体力・経験値の棒と、スキルバーは、小さい
	t.check(Hud.BAR_W <= 100.0 and Hud.BAR_H <= 12.0, "体力・経験値の棒は小さめ")
	t.check(SkillBar.BAR_SCALE <= 0.8, "スキルバーは小さめ")
	main.queue_free()


func test_skills_turn_toward_a_nearby_enemy() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	var enemy: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy:
			enemy = n
			break
	player.global_position = enemy.global_position + Vector2(-30, 0)
	player.facing = 6  # 上を向いていても、近くの敵のほうへ
	var nearest := player.nearest_enemy()
	t.check(nearest != null, "近くに敵がいる")
	t.check_eq(player.aim_target(), nearest.global_position, "いちばん近い敵の位置を狙う")
	# 敵が範囲の外なら、向いている方向
	player.global_position = enemy.global_position + Vector2(-100000, 0)
	t.check(player.nearest_enemy() == null, "遠いときは自動で狙わない")
	main.queue_free()


func test_enemy_hit_hurts_player() -> void:
	var main: Node = await _start_main()
	var player := (t as SceneTree).get_first_node_in_group("player") as Player
	var manager: EnemyManager = main.get_node("World/EnemyManager")
	var before: float = player.vitals.life
	var source: Enemy = (t as SceneTree).get_nodes_in_group("enemies").filter(func(n: Node) -> bool: return n is Enemy)[0]
	manager.player_hit.emit(10.0, source)
	t.check(player.vitals.life < before, "敵に殴られると体力が減る")
	main.queue_free()


func test_kill_gives_xp_and_drops() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	var xp_before: int = player.vitals.xp
	var enemy: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy and n.definition.xp > 0:
			enemy = n
			break
	t.check(enemy != null, "経験値を持つ敵がいる")
	if enemy == null:
		main.queue_free()
		return
	var skill: SkillDef = DataDB.skill("slash")
	enemy.take_hit(enemy.life + 1.0, skill)
	t.check(player.vitals.xp > xp_before or player.vitals.level > 1, "倒すと経験値が入る")
	main.queue_free()


func test_floor_check_and_drops_avoid_walls() -> void:
	var main: Node = await _start_main()
	var map: IsoMap = main.map
	t.check(map.is_floor_at(map.marker("P")), "プレイヤーの開始位置は床")
	var wall_pos: Vector2 = map.floor_layer.map_to_local(Vector2i(0, 0))  # マップの左上は壁
	t.check(not map.is_floor_at(wall_pos), "壁のマスは床ではない")
	t.check(not map.is_floor_at(wall_pos, true), "壁のマスは壁ぎわ判定でも床ではない")
	# 壁ぎわの床（左端の列のすぐ内側）は、margin 付きでは置けない
	var edge_pos: Vector2 = map.floor_layer.map_to_local(Vector2i(2, 2))  # 開始の広場の角（北と西が壁）
	t.check(map.is_floor_at(edge_pos) and not map.is_floor_at(edge_pos, true), "壁ぎわは余白付きの判定で除外される")
	# 壁ぎわの敵を倒しても、ドロップは壁の中・壁ぎわに置かれない
	var director: LootDirector = null
	for child: Node in main.get_children():
		if child is LootDirector:
			director = child
	t.check(director != null and director.is_valid_position.is_valid(), "ドロップの管理に置き場所の判定がつながっている")
	if director != null:
		var bad := 0
		for i in 200:
			var pos: Vector2 = director._scatter_position(edge_pos)
			if pos != edge_pos and not map.is_floor_at(pos, true):
				bad += 1
		t.check_eq(bad, 0, "散らした位置が壁の中・壁ぎわにならない")
	main.queue_free()


func test_start_room_chest_opens_once_and_drops() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var chests: Array[Node] = tree.get_nodes_in_group("chests")
	t.check_eq(chests.size(), (main.map.markers.get("C", []) as Array).size(), "マップの印の数だけ宝箱がある")
	if chests.is_empty():
		main.queue_free()
		return
	var player := tree.get_first_node_in_group("player") as Player
	var chest := chests[0] as TreasureChest  # 開始位置にいちばん近い宝箱（最初の広場のもの）
	for c: Node in chests:
		if c.global_position.distance_to(player.global_position) < chest.global_position.distance_to(player.global_position):
			chest = c as TreasureChest
	t.check(Iso.ground_distance(chest.global_position, player.global_position) < 200.0, "最初の広場に宝箱がある")
	t.check(not chest.is_open, "最初は閉じている")
	var director: LootDirector = null
	for child: Node in main.get_children():
		if child is LootDirector:
			director = child
	var before: int = director.active_count()
	player.global_position = chest.global_position + Vector2(4, 0)
	for i in 5:
		await tree.physics_frame
	t.check(chest.is_open, "近づくと開く")
	var after_open: int = director.active_count()
	t.check(after_open > before, "開けるとドロップが地面に出る")
	chest.open()
	t.check_eq(director.active_count(), after_open, "2回目は開かない（中身は1回だけ）")
	main.queue_free()


func test_equipment_stats_reach_player() -> void:
	var main: Node = await _start_main()
	var player := (t as SceneTree).get_first_node_in_group("player") as Player
	var life_before: float = player.vitals.max_life()
	# 持ち物に装備を入れたら、プレイヤーの最大ライフに反映される
	var stash: Stash = main.stash
	t.check(stash != null, "メイン画面が持ち物を持っている")
	var item: ItemInstance = null
	var roller := LootRoller.new(RandomNumberGenerator.new())
	for i in 200:
		var candidate: ItemInstance = roller.roll_item(10)
		if candidate != null and float(candidate.total_stats().get("life", 0.0)) > 0.0:
			item = candidate
			break
	t.check(item != null, "ライフが付く装備を抽選で作れる")  # 作れないときに、黙って通らないようにする
	if item == null:
		main.queue_free()
		return
	stash.collect(item)
	t.check(player.vitals.max_life() > life_before, "装備の life が最大ライフに足される")
	main.queue_free()


func test_dodge_moves_and_avoids_damage() -> void:
	var main: Node = await _start_main()
	var player := (t as SceneTree).get_first_node_in_group("player") as Player
	player.global_position = Vector2(100000, 100000)
	player.facing = 0  # 右向き
	var start := player.global_position
	var life: float = player.vitals.life
	t.check(player.start_dodge(), "回避できる")
	t.check(player.is_invulnerable(), "回避中は無敵")
	player.on_player_hit(10.0, null)
	t.check_eq(player.vitals.life, life, "回避中は、攻撃を受けない")
	t.check(not player.start_dodge(), "連続では回避できない（再使用時間）")
	for i in 20:
		await (t as SceneTree).physics_frame
	t.check(player.global_position.x > start.x + 20.0, "向いている方向へ動く")
	player._invuln_left = 0.0
	player.on_player_hit(10.0, null)
	t.check(player.vitals.life < life, "回避が終わると、攻撃を受ける")
	player._dodge_cooldown_left = 0.0
	t.check(player.start_dodge(Vector2.UP), "時間がたてば、もう一度回避できる")
	main.queue_free()


func test_dps_meter() -> void:
	var meter := DpsMeter.new()
	(t as SceneTree).root.add_child(meter)
	t.check_eq(meter.current_dps(), 0.0, "最初は0")
	meter.record(100.0)
	meter.tick(0.1)
	t.check_eq(meter.current_dps(), 100.0, "最初の1秒は、1秒で割る（1発で跳ね上がらない）")
	meter.record(100.0)
	meter.tick(1.9)
	t.check(absf(meter.current_dps() - 100.0) < 0.01, "2秒で200なら、100")
	t.check(meter.peak_dps() >= 100.0, "最大値を覚える")
	meter.tick(DpsMeter.WINDOW + 1.0)
	t.check_eq(meter.current_dps(), 0.0, "攻撃をやめると、0に戻る")
	t.check(meter.peak_dps() >= 100.0, "最大値は残る")
	t.check(meter._label.text.contains("DPS"), "画面に出る")
	meter.free()


func test_main_wires_dps_and_damage_taken() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var meter: DpsMeter = null
	for child: Node in main.get_children():
		if child is DpsMeter:
			meter = child
	t.check(meter != null, "メイン画面に DPS 表示がある")
	var enemy: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy and n.definition.life > 100.0:
			enemy = n
			break
	enemy.take_hit(50.0, DataDB.skill("slash"))
	t.check_eq(meter._hits.size(), 1, "与えたダメージが DPS に入る")
	var dummy: TrainingDummy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is TrainingDummy:
			dummy = n
			break
	dummy.take_hit(30.0, DataDB.skill("slash"))
	t.check_eq(meter._hits.size(), 2, "案山子への攻撃も DPS に入る")
	main.queue_free()


func test_autopilot_walks_to_enemy_fights_and_dodges() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	var pilot: Autopilot = main.autopilot
	t.check(not pilot.enabled, "最初は切れている")
	t.check_eq(pilot.toggle(), true, "F2 で入る")
	t.check(pilot.director != null, "落ちているものを探せる")
	# 敵のいる場所へ行って、スキルを使う
	var enemy: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy and n.definition.behavior == "melee_swarm":
			enemy = n
			break
	player.global_position = enemy.global_position + Vector2(-100, 0)
	var chosen: Node2D = pilot.find_target(player)
	t.check(chosen is Enemy, "近くの敵を選ぶ")
	var move: Vector2 = pilot.move_input(player, 0.016)
	t.check(move.length() > 0.5, "敵のほうへ（道に沿って）歩く")
	player.global_position = chosen.global_position + Vector2(-10, 0)
	t.check_eq(pilot.move_input(player, 0.016), Vector2.ZERO, "近づいたら止まって戦う")
	t.check(pilot.wants_skill(player), "近くに敵がいれば、スキルを使う")
	player.global_position = Vector2(100000, 100000)
	t.check(not pilot.wants_skill(player), "敵が近くにいなければ、使わない")
	# 近くで突進の予告が始まったら避ける
	var boss: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy and n.definition.is_boss:
			boss = n
	player.global_position = boss.global_position + Vector2(60, 0)
	t.check(not pilot.wants_dodge(player), "予告がなければ避けない")
	boss.charge_phase = 1
	t.check(pilot.wants_dodge(player), "突進の予告が近くで始まったら避ける")
	t.check(pilot.dodge_direction != Vector2.ZERO, "避ける向きがある")
	boss.charge_phase = 0
	t.check_eq(pilot.toggle(), false, "もう一度 F2 で切れる")
	main.queue_free()


func test_autopilot_actually_plays() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	var start: Vector2 = player.global_position
	main.set_autopilot(true)
	var hits: Array[int] = [0]
	var manager: EnemyManager = main.get_node("World/EnemyManager")
	manager.enemy_hit.connect(func(_e: Enemy, _a: float, _k: bool) -> void: hits[0] += 1)
	for i: int in 900:
		await tree.physics_frame
	t.check(player.global_position.distance_to(start) > 20.0, "自動戦闘で、勝手に歩く")
	t.check(hits[0] > 0, "自動戦闘で、敵や案山子に攻撃が当たる")
	main.queue_free()


func test_autopilot_finds_paths_around_walls_and_options() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	var pilot: Autopilot = main.autopilot
	var map: IsoMap = main.map
	# 開始地点から、ボスの部屋・すべての宝箱へ、道がつながっている
	var boss_pos: Vector2 = map.marker("X")
	t.check(pilot.path_length(map.marker("P"), boss_pos) > 20, "開始地点からボスの部屋まで、歩いて行ける道がある")
	for chest_pos: Vector2 in map.markers.get("C", []):
		t.check(pilot.path_length(map.marker("P"), chest_pos) >= 0, "宝箱へ歩いて行ける")
	# 壁の向こうの目的地へ、まっすぐではなく、道に沿った向きに歩く
	player.global_position = map.marker("P")
	pilot.toggle()
	pilot.route = Autopilot.Route.BOSS_RUSH
	pilot.open_chests = false
	var steered: Vector2 = pilot.move_input(player, 0.016)
	t.check_eq(pilot.goal_kind, "ボス", "ボスへ直行のとき、目的地はボス")
	t.check(steered.length() > 0.5, "道に沿って歩き出す")
	# 設定の切り替え
	pilot.route = Autopilot.Route.NEAREST_ENEMY
	pilot.cycle_route()
	t.check_eq(pilot.route, Autopilot.Route.BOSS_RUSH, "ルートを切り替えられる")
	pilot.cycle_route()
	t.check_eq(pilot.route, Autopilot.Route.NEAREST_ENEMY, "ルートは一周する")
	pilot.open_chests = true
	t.check_eq(pilot.toggle_chests(), false, "宝箱を開けない設定にできる")
	t.check_eq(pilot.toggle_chests(), true, "もう一度で、開ける設定に戻る")
	t.check(pilot.settings_text().contains("ルート") and pilot.settings_text().contains("宝箱"), "設定が画面に出る")
	# 宝箱を開ける設定なら、近くの敵がいないとき、宝箱へ向かう。開けない設定なら向かわない
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy:
			n.hide()  # 敵を見えなくして、宝箱だけを見る
	var chest: TreasureChest = tree.get_nodes_in_group("chests")[0] as TreasureChest
	player.global_position = chest.global_position + Vector2(60, 0)
	pilot.open_chests = true
	pilot.move_input(player, 0.016)
	t.check_eq(pilot.goal_kind, "宝箱", "宝箱を開ける設定なら、宝箱へ向かう")
	pilot.open_chests = false
	pilot.move_input(player, 0.016)
	t.check(pilot.goal_kind != "宝箱", "開けない設定なら、宝箱へ寄り道しない")
	main.queue_free()


func test_autopilot_reaches_far_goal_through_corridors() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	var pilot: Autopilot = main.autopilot
	var map: IsoMap = main.map
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy:
			n.hide()
			n.active = false
	player.global_position = map.marker("P")
	# 開始の広場から、最初の宝箱へ（壁をまわって、歩いて着く）
	var chest: TreasureChest = tree.get_nodes_in_group("chests")[0] as TreasureChest
	for c: Node in tree.get_nodes_in_group("chests"):
		if pilot.path_length(player.global_position, c.global_position) < pilot.path_length(player.global_position, chest.global_position):
			chest = c as TreasureChest
	pilot.toggle()
	pilot.open_chests = true
	for i: int in 1800:
		await tree.physics_frame
		if chest.is_open:
			break
	t.check(chest.is_open, "壁にぶつからず、道に沿って宝箱まで歩いて、開けた")
	main.queue_free()


func test_heal_charges_and_autopilot_heal() -> void:
	var vitals := PlayerVitals.new()
	t.check_eq(vitals.heal_charges, 3, "回復は、はじめ3回")
	t.check_eq(vitals.use_heal(), 0.0, "ライフが満タンなら、使えない")
	t.check_eq(vitals.heal_charges, 3, "満タンでは、回数は減らない")
	var healed: Array[float] = []
	vitals.healed.connect(func(amount: float) -> void: healed.append(amount))
	vitals.life = 20.0
	var amount: float = vitals.use_heal()
	t.check_eq(amount, vitals.max_life() * PlayerVitals.HEAL_RATIO, "最大ライフの半分を回復する")
	t.check_eq(vitals.life, 20.0 + amount, "ライフが増える")
	t.check_eq(vitals.heal_charges, 2, "回数が1減る")
	t.check_eq(healed.size(), 1, "回復の信号が出る")
	vitals.life = vitals.max_life() - 5.0
	t.check_eq(vitals.use_heal(), 5.0, "満タンを超えては回復しない")
	vitals.life = 1.0
	vitals.use_heal()
	t.check_eq(vitals.heal_charges, 0, "使い切った")
	vitals.life = 1.0
	t.check_eq(vitals.use_heal(), 0.0, "0回なら使えない")
	vitals.reset()
	t.check_eq(vitals.heal_charges, 3, "やり直しで3回に戻る")


func test_autopilot_heals_at_20_percent_loss_and_clears_all() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	var pilot: Autopilot = main.autopilot
	var max_life: float = player.vitals.max_life()
	player.vitals.life = max_life * 0.5
	t.check(not pilot.wants_heal(player), "半分あっても使わない（勝手に使わない）")
	player.vitals.life = max_life * 0.25
	t.check(not pilot.wants_heal(player), "残り2割より多いうちは使わない")
	player.vitals.life = max_life * 0.2
	t.check(pilot.wants_heal(player), "残り2割になったら使う")
	player.vitals.heal_charges = 0
	t.check(not pilot.wants_heal(player), "回数がなければ使わない")
	player.vitals.heal_charges = 3
	pilot.toggle()
	player.vitals.life = max_life * 0.15
	for i: int in 3:
		await tree.physics_frame
	t.check(player.vitals.heal_charges < 3 and player.vitals.life > max_life * 0.15, "自動戦闘が、回復を使った")
	player.global_position = main.map.marker("P")
	pilot.open_chests = false
	pilot.director = null  # 落ちているものは見ない（宝箱から出たものに寄らないように）
	pilot.route = Autopilot.Route.NEAREST_ENEMY
	pilot.move_input(player, 0.016)
	t.check_eq(pilot.goal_kind, "敵", "全滅ルートは、敵を目指す")
	var target: Node2D = pilot._nearest_by_path(player)
	t.check(target != null and not (target as Enemy).definition.is_boss, "ボスは、ほかの敵を倒しきってから")
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy:
			n.take_hit(1000000.0, DataDB.skill("slash"))
	pilot.move_input(player, 0.016)
	t.check(pilot.cleared, "敵を全滅させたと分かる")
	t.check(pilot.settings_text().contains("全滅"), "全滅が画面に出る")
	main.queue_free()
