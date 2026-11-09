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
	t.check(loot_hud != null and loot_hud._panel.visible, "スタート直後は、スタート構成のお知らせが出ている")
	loot_hud._recent.clear()  # お知らせが消えたあと
	loot_hud._refresh()
	t.check(not loot_hud._panel.visible, "通知がないあいだは、枠が出ない")
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
	pilot.director = null  # 宝箱から出たドロップに、目的地が引っぱられないように
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


func test_autopilot_ignores_unreachable_drops_and_fights_the_room() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	var pilot: Autopilot = main.autopilot
	var map: IsoMap = main.map
	pilot.toggle()
	pilot.open_chests = false
	pilot.route = Autopilot.Route.NEAREST_ENEMY
	player.global_position = map.marker("P")
	# 壁の中に落ちているもの（行けない）は、拾いに行かず、敵のほうへ向かう
	var director: LootDirector = pilot.director
	var wall_pos: Vector2 = map.floor_layer.map_to_local(Vector2i(0, 0)) + Vector2(0, 0)
	director.spawn_drop(5, wall_pos)
	pilot.move_input(player, 0.016)
	t.check(pilot.goal_kind != "拾う", "壁の中のドロップは、拾いに行かない")
	t.check(pilot.goal_kind == "敵", "代わりに、敵の部屋へ向かう")
	# 行ける場所のドロップは、拾いに行く
	director.spawn_drop(5, map.marker("P") + Vector2(40, 0))
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy:
			n.hide()
	pilot.move_input(player, 0.016)
	t.check_eq(pilot.goal_kind, "拾う", "行けるドロップは拾いに行く")
	main.queue_free()


func test_autopilot_clears_rooms_before_chests_and_boss() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	var pilot: Autopilot = main.autopilot
	var map: IsoMap = main.map
	pilot.toggle()
	pilot.director = null
	pilot.open_chests = true
	pilot.route = Autopilot.Route.NEAREST_ENEMY
	var chests: Array[Node] = tree.get_nodes_in_group("chests")
	# すぐ近くの宝箱は、素通りせずに開ける
	var near_chest: TreasureChest = null
	for c: Node in chests:
		if near_chest == null or Iso.ground_distance(c.global_position, map.marker("P")) < Iso.ground_distance(near_chest.global_position, map.marker("P")):
			near_chest = c as TreasureChest
	player.global_position = near_chest.global_position + Vector2(40, 0)
	pilot.move_input(player, 0.016)
	t.check_eq(pilot.goal_kind, "宝箱", "すぐ近くの宝箱は、素通りせずに開ける")
	# 遠い宝箱しか残っていないあいだは、敵を先に倒す
	var far_chest: TreasureChest = null
	for c2: Node in chests:
		if far_chest == null or Iso.ground_distance(c2.global_position, map.marker("P")) > Iso.ground_distance(far_chest.global_position, map.marker("P")):
			far_chest = c2 as TreasureChest
	for c3: Node in chests:
		(c3 as TreasureChest).is_open = c3 != far_chest
	player.global_position = map.marker("P")
	pilot.move_input(player, 0.016)
	t.check_eq(pilot.goal_kind, "敵", "遠い宝箱は、敵が残っているあいだは後回し")
	# ボス以外を全部倒したら、遠い宝箱へ
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy and not n.definition.is_boss:
			n.take_hit(1000000.0, DataDB.skill("slash"))
	pilot.move_input(player, 0.016)
	t.check_eq(pilot.goal_kind, "宝箱", "ボス以外を倒したら、遠い宝箱へも行く")
	# 宝箱を全部開けたら、ボスへ
	far_chest.is_open = true
	pilot.move_input(player, 0.016)
	t.check_eq(pilot.goal_kind, "ボス", "宝箱が済んだら、ボスへ")
	# ボスの部屋には、宝箱を置かない
	var boss: Enemy = pilot.find_boss(player) as Enemy
	for c4: Node in chests:
		t.check(Iso.ground_distance(c4.global_position, boss.global_position) > Autopilot.BOSS_AVOID_DISTANCE, "ボスの部屋のまわりに、宝箱はない")
	main.queue_free()

func test_walk_animation_frames() -> void:
	for view: String in Player.WALK_VIEWS:
		for i: int in 4:
			var tex: Texture2D = load("res://art/sprites/player/player_walk_%s_%d.png" % [view, i])
			var expected: Vector2 = Vector2(36, 30) if view.begins_with("diag") else Vector2(30, 30)
			t.check(tex != null and tex.get_size() == expected, "歩きの絵 %s の%dコマ目（%s）" % [view, i, str(expected)])
			var img: Image = tex.get_image()
			var opaque: int = 0
			for y: int in 30:
				for x: int in 30:
					if img.get_pixel(x, y).a > 0.5:
						opaque += 1
			t.check(opaque > 150, "歩きの絵 %s の%dコマ目に、キャラが描かれている" % [view, i])
	# 時刻で、4コマが順に出る。斜めは歩きの絵がない（立ち絵の脚を動かす）
	var seen: Dictionary = {}
	for step: int in 4:
		seen[Player.walk_texture("front", step * Player.WALK_FRAME_MS)] = true
	t.check_eq(seen.size(), 4, "4コマが順に出る")
	t.check(Player.walk_texture("diag_down", 0) != null and Player.walk_texture("diag_up", 0) != null, "斜めにも、歩きの絵がある")


func test_attack_animation_frames() -> void:
	for view: String in Player.ATTACK_VIEWS:
		for i: int in Player.ATTACK_FRAMES:
			var tex: Texture2D = load("res://art/sprites/player/player_attack_%s_%d.png" % [view, i])
			var size: Vector2 = Vector2(56, 40) if view.begins_with("diag") else Vector2(48, 40)
			t.check(tex != null and tex.get_size() == size, "攻撃の絵 %s の%dコマ目（%s）" % [view, i, str(size)])
			var img: Image = tex.get_image()
			var opaque: int = 0
			for y: int in 40:
				for x: int in int(size.x):
					if img.get_pixel(x, y).a > 0.5:
						opaque += 1
			t.check(opaque > 150, "攻撃の絵 %s の%dコマ目に、キャラが描かれている" % [view, i])
	var seen: Dictionary = {}
	for i: int in Player.ATTACK_FRAMES:
		seen[Player.attack_texture("side", float(i) * Player.ATTACK_FRAME_SECONDS + 0.001)] = true
	t.check_eq(seen.size(), 5, "5コマが順に出る")
	t.check(Player.attack_texture("diag_up", 0.0) != null and Player.attack_texture("diag_down", 0.0) != null, "斜めにも、攻撃の絵がある")
	# 再生：スキルを使うと始まり、5コマぶん たつと終わる
	var player := Player.new()
	t.check(not player.is_attack_animating(), "最初は再生していない")
	player.play_attack_animation()
	t.check(player.is_attack_animating(), "スキルを使うと再生が始まる")
	player.free()


func test_golem_animation_frames_and_state() -> void:
	for anim: String in ["rockgolem_walk", "rockgolem_attack"]:
		var count: int = 4 if anim.ends_with("walk") else 5
		for i: int in count:
			var tex: Texture2D = load("res://art/sprites/enemies/%s_%d.png" % [anim, i])
			t.check(tex != null and tex.get_size() == Vector2(40, 32), "岩殻の絵 %s の%dコマ目（40x32）" % [anim, i])
			var img: Image = tex.get_image()
			var opaque: int = 0
			for y: int in 32:
				for x: int in 40:
					if img.get_pixel(x, y).a > 0.5:
						opaque += 1
			t.check(opaque > 200, "岩殻の絵 %s の%dコマ目に、岩が描かれている" % [anim, i])
	var enemy := Enemy.new()
	enemy.definition = EnemyDef.new()
	enemy.definition.behavior = "tank"
	t.check(enemy.golem_anim_texture() == null, "立っているときは、立ち絵（動きの絵なし）")
	enemy.state = Enemy.State.CHASING
	t.check(enemy.golem_anim_texture() != null, "歩いているときは、歩きの絵")
	enemy.state = Enemy.State.WINDUP
	t.check(enemy.golem_anim_texture() == Enemy.anim_texture("rockgolem_attack", 1), "殴る前は、腕を振り上げた絵")
	enemy.state = Enemy.State.ATTACKING
	enemy.play_strike()
	t.check(enemy.golem_anim_texture() == Enemy.anim_texture("rockgolem_attack", 2), "叩きつけた瞬間は、叩きつけの絵")
	enemy.free()


func test_slime_animation_frames_and_state() -> void:
	var expected: Dictionary = {"slime_move": 4, "slime_attack": 4, "spitter_move": 4, "spitter_attack": 4}
	for anim: String in expected:
		for i: int in int(expected[anim]):
			var tex: Texture2D = load("res://art/sprites/enemies/%s_%d.png" % [anim, i])
			t.check(tex != null and tex.get_size() == Vector2(24, 18), "スライムの絵 %s の%dコマ目（24x18）" % [anim, i])
			var img: Image = tex.get_image()
			var opaque: int = 0
			for y: int in 18:
				for x: int in 24:
					if img.get_pixel(x, y).a > 0.5:
						opaque += 1
			t.check(opaque > 40, "スライムの絵 %s の%dコマ目に、スライムが描かれている" % [anim, i])
	var slime := Enemy.new()
	slime.definition = EnemyDef.new()
	slime.definition.behavior = "melee_swarm"
	t.check(slime.current_anim_texture() == Enemy.anim_texture("slime_move", 0), "待機は、跳ねる動きの最初のコマ")
	slime.state = Enemy.State.CHASING
	t.check(slime.current_anim_texture() != null, "動いているときは、跳ねる絵")
	slime.play_strike()
	t.check(slime.current_anim_texture() == Enemy.anim_texture("slime_attack", 0), "体当たりの瞬間は、体当たりの絵")
	slime.free()
	var spitter := Enemy.new()
	spitter.definition = EnemyDef.new()
	spitter.definition.behavior = "ranged"
	spitter.definition.shot_windup = 0.5
	spitter.shot_windup_left = 0.45
	t.check(spitter.current_anim_texture() == Enemy.anim_texture("spitter_attack", 0), "吐く前のため（前半）は、縮んだ絵")
	spitter.shot_windup_left = 0.1
	t.check(spitter.current_anim_texture() == Enemy.anim_texture("spitter_attack", 1), "吐く前のため（後半）は、膨らんだ絵")
	spitter.shot_windup_left = 0.0
	spitter.play_strike()
	t.check(spitter.current_anim_texture() == Enemy.anim_texture("spitter_attack", 2), "吐いた瞬間は、吐く絵")
	spitter.free()


func test_death_animation_layer() -> void:
	var tree: SceneTree = t
	for anim: String in ["slime_death", "spitter_death", "rockgolem_death"]:
		var count: int = int(DeathAnimLayer.FRAMES[anim])
		for i: int in count:
			var tex: Texture2D = load("res://art/sprites/enemies/%s_%d.png" % [anim, i])
			t.check(tex != null, "死ぬ動きの絵 %s の%dコマ目がある" % [anim, i])
		t.check(Enemy.anim_texture(anim, count) == null, "%s は %d コマで終わる" % [anim, count])
	var manager := EnemyManager.new()
	tree.root.add_child(manager)
	manager.set_physics_process(false)
	var slime: Enemy = manager.spawn(DataDB.enemy("swarmling"), Vector2(10, 10))
	t.check_eq(manager.death_anim_count(), 0, "最初は、死ぬ動きはない")
	slime.take_hit(slime.life + 1.0, DataDB.skill("slash"))
	t.check_eq(manager.death_anim_count(), 1, "倒すと、死ぬ動きが1つ出る")
	var golem: Enemy = manager.spawn(DataDB.enemy("brute"), Vector2(40, 10))
	golem.take_hit(golem.life + 1.0, DataDB.skill("slash"))
	t.check_eq(manager.death_anim_count(), 2, "岩殻を倒しても、出る")
	var layer: DeathAnimLayer = manager._death_layer
	layer._process(5.0)
	t.check_eq(manager.death_anim_count(), 0, "時間がたてば、消える")
	# 案山子など、絵のない敵は、何もしない
	var dummy_def := EnemyDef.new()
	dummy_def.behavior = "dummy"
	layer.play(dummy_def, Vector2.ZERO)
	t.check_eq(layer.active_count(), 0, "絵のない敵は、何も出さない")
	manager.queue_free()
	await tree.process_frame


func test_autopilot_prioritizes_chain_skills() -> void:
	var player := Player.new()
	var pilot := Autopilot.new()
	t.check_eq(pilot.skill_mode, Autopilot.SkillMode.ALL_READY, "標準は、出せるものを全部出す（DPSがいちばん高い）")
	pilot.skill_mode = Autopilot.SkillMode.CHAIN_PRIORITY
	pilot.chain_wait_seconds = 0.5
	var caster: SkillCaster = player.caster
	caster.loadout.set_skill(1, "slash")  # 近接
	caster.loadout.set_skill(2, "frost_bloom")  # 冷気の範囲（→ 近接で「砕氷」）
	caster.loadout.set_skill(3, "fire_bolt")
	# 何も出していないとき：チェインの1発目になれる霜囲い（相棒の払いが出せる）を先に出す
	t.check_eq(pilot.pick_skill_slot(player), 2, "チェインの1発目になるスキルを先に出す")
	# 霜囲いを出したあと：払いを出せばチェインが完成するので、それを出す
	caster.chain.on_cast(caster.loadout.skill(2), DataDB.chains, DataDB.skills)
	caster._cooldowns[1] = 3.0  # 霜囲いは再使用待ち
	t.check_eq(pilot.pick_skill_slot(player), 1, "チェインを完成させるスキルを、ほかより先に出す")
	# 相棒（払い）がもうすぐ使えるなら、ほかのスキル（火の矢）を出さずに待つ
	caster._cooldowns[0] = 0.3
	t.check_eq(pilot.pick_skill_slot(player), 0, "相棒がもうすぐなら、待つ（チェインを切らさない）")
	# 相棒が当分使えなければ、待たずにほかのスキルを出す
	caster._cooldowns[0] = 5.0
	t.check_eq(pilot.pick_skill_slot(player), 3, "相棒が当分使えないなら、ほかのスキルを出す")
	# チェインがまったく組めないときは、出せるものを、枠の順に出す
	caster.chain.reset()
	caster._cooldowns[0] = 0.0
	caster._cooldowns[1] = 0.0
	caster.loadout.clear_skill(1)
	caster.loadout.clear_skill(2)
	t.check_eq(pilot.pick_skill_slot(player), 3, "チェインがなければ、出せるスキルを出す")
	caster._cooldowns[2] = 2.0
	t.check_eq(pilot.pick_skill_slot(player), 0, "出せるスキルがなければ 0")
	player.free()


func test_autopilot_default_casts_all_ready_skills() -> void:
	var player := Player.new()
	var pilot := Autopilot.new()
	player.caster.loadout.set_skill(1, "slash")
	player.caster.loadout.set_skill(2, "frost_bloom")
	player.caster.loadout.set_skill(3, "fire_bolt")
	t.check_eq(pilot.skills_to_cast(player), [1, 2, 3] as Array[int], "標準は、出せるスキルを全部、枠の順に出す")
	player.caster._cooldowns[1] = 1.0
	t.check_eq(pilot.skills_to_cast(player), [1, 3] as Array[int], "再使用待ちのものは出さない")
	player.free()


func test_autopilot_auto_equips_best_owned_supports() -> void:
	var player := Player.new()
	var pilot := Autopilot.new()
	var stash := Stash.new()  # 初期の補助ジェム：拡散・撃破時爆発
	pilot.stash = stash
	var loadout: SkillLoadout = player.caster.loadout
	loadout.set_skill(1, "slash")  # 近接
	loadout.set_skill(2, "frost_bloom")  # 範囲
	loadout.set_skill(3, "fire_bolt")  # 飛び道具
	t.check(Autopilot.support_score(DataDB.support("scatter")) > Autopilot.support_score(DataDB.support("rapid_cast")), "拡散は、連続使用より、評価が高い")
	t.check_eq(pilot.equip_supports(player.caster), 3, "3つの枠に、補助ジェムがつく")
	t.check_eq(loadout.support_id(1), "burst_on_kill", "近接には、拡散は付けられないので、撃破時爆発")
	t.check_eq(loadout.support_id(2), "burst_on_kill", "範囲にも、撃破時爆発")
	t.check_eq(loadout.support_id(3), "scatter", "飛び道具には、拡散")
	t.check_eq(pilot.equip_supports(player.caster), 0, "もう一度やっても、変わらない")
	# 持っていない補助ジェムは付けない。新しく持てば、良ければ付け替える
	t.check(not stash.has_gem(GemInstance.Kind.SUPPORT, "chain_hop"), "飛び跳ねは、まだ持っていない")
	stash.add_gem(GemInstance.new(GemInstance.Kind.SUPPORT, "chain_hop"))
	t.check_eq(pilot.equip_supports(player.caster), 0, "拡散より弱い補助ジェムを拾っても、付け替えない")
	player.free()


func test_start_loadout_is_random_and_always_has_a_chain() -> void:
	var seen: Dictionary = {}
	for seed_value: int in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var ids: Array[String] = StartLoadout.roll(rng)
		t.check_eq(ids.size(), 3, "スキルは3つ（seed %d）" % seed_value)
		var skills: Array[SkillDef] = []
		for id: String in ids:
			var skill: SkillDef = DataDB.skill(id)
			t.check(skill != null and not skill.chain_only, "ふつうのスキル: %s" % id)
			skills.append(skill)
		t.check(not StartLoadout.chain_pairs(skills).is_empty(), "チェインが1つは組める（seed %d: %s）" % [seed_value, str(ids)])
		var sorted_ids: Array[String] = ids.duplicate()
		sorted_ids.sort()
		t.check_eq(sorted_ids.size(), 3, "同じスキルがない")
		t.check(sorted_ids[0] != sorted_ids[1] and sorted_ids[1] != sorted_ids[2], "3つとも違う（seed %d）" % seed_value)
		seen[",".join(sorted_ids)] = true
	t.check(seen.size() >= 8, "いろいろな構成が出る（%d 通り）" % seen.size())
	var sample: Array[String] = ["frost_bloom", "slash", "fire_bolt"]
	t.check(StartLoadout.describe(sample).contains("チェイン"), "お知らせに、組めるチェインが出る")


func test_main_uses_random_start_loadout() -> void:
	var main: Node = await _start_main()
	var player := (t as SceneTree).get_first_node_in_group("player") as Player
	t.check_eq(main.start_skill_ids.size(), 3, "メイン画面が、スタート構成を決めている")
	for slot: int in 3:
		t.check_eq(player.caster.loadout.skill_id(slot + 1), main.start_skill_ids[slot], "枠 %d に、決めたスキルが入っている" % (slot + 1))
		t.check(main.stash.has_gem(GemInstance.Kind.SKILL, main.start_skill_ids[slot]), "持ち物に、そのスキルがある")
	var skills: Array[SkillDef] = []
	for id: String in main.start_skill_ids:
		skills.append(DataDB.skill(id))
	t.check(not StartLoadout.chain_pairs(skills).is_empty(), "実際の構成でも、チェインが組める")
	t.check(main.start_loadout_text.begins_with("スタート構成"), "お知らせの文がある")
	main.queue_free()


func test_skill_screen_can_change_the_third_slot() -> void:
	var tree: SceneTree = t
	var caster := SkillCaster.new()
	tree.root.add_child(caster)
	var stash := Stash.new()
	var screen := SkillScreen.new()
	tree.root.add_child(screen)
	screen.setup(caster, stash)
	t.check_eq(SkillScreen.VISIBLE_SLOTS, 3, "装備画面に、3つの枠が出る")
	t.check_eq(caster.loadout.skill_id(3), "fire_bolt", "3つ目の枠は、はじめ火の矢")
	screen._selected_slot = 3
	screen._select_support = false
	t.check(screen._equip("frost_bloom"), "3つ目の枠のスキルを、付け替えられる")
	t.check_eq(caster.loadout.skill_id(3), "frost_bloom", "3つ目の枠が、変わっている")
	screen._select_support = true
	t.check(screen._equip("burst_on_kill"), "3つ目の枠の補助ジェムも、付け替えられる")
	t.check_eq(caster.loadout.support_id(3), "burst_on_kill", "3つ目の補助が、変わっている")
	screen.queue_free()
	caster.queue_free()
	await tree.process_frame


func test_auto_loop_restarts_after_boss_or_death_only_in_auto() -> void:
	var tree: SceneTree = t
	var manager := EnemyManager.new()
	tree.root.add_child(manager)
	manager.set_physics_process(false)
	var player := Player.new()
	tree.root.add_child(player)
	var pilot := Autopilot.new()
	var loop := AutoLoop.new()
	tree.root.add_child(loop)
	loop.setup(manager, player, pilot)
	var restarts: Array[String] = []
	loop.restart_requested.connect(func(reason: String, _run: int) -> void: restarts.append(reason))
	Autopilot.runs = 0
	var boss_def: EnemyDef = DataDB.enemy("rock_lord")
	var boss: Enemy = manager.spawn(boss_def, Vector2(500, 500))
	# 手で遊んでいる（自動戦闘が切れている）ときは、ボスを倒しても、やり直さない
	boss.take_hit(boss.life + 1.0, DataDB.skill("slash"))
	loop.tick(100.0)
	t.check_eq(restarts.size(), 0, "手で遊んでいるときは、勝手にやり直さない")
	# 自動戦闘が入っていれば、ボスを倒して、少し待ってから、やり直す
	pilot.enabled = true
	var boss2: Enemy = manager.spawn(boss_def, Vector2(500, 500))
	boss2.take_hit(boss2.life + 1.0, DataDB.skill("slash"))
	t.check(loop.is_waiting(), "ボスを倒すと、やり直しを待つ")
	loop.tick(AutoLoop.BOSS_WAIT_SECONDS - 1.0)
	t.check_eq(restarts.size(), 0, "ドロップを拾う時間のあいだは、やり直さない")
	loop.tick(1.5)
	t.check_eq(restarts, ["boss"] as Array[String], "待ったあと、やり直す")
	t.check_eq(Autopilot.runs, 1, "周回の数が増える")
	# やられたときも、やり直す
	player.vitals.take_damage(100000.0)
	t.check(loop.is_waiting(), "やられても、やり直しを待つ")
	loop.tick(AutoLoop.DEATH_WAIT_SECONDS + 0.1)
	t.check_eq(restarts, ["boss", "death"] as Array[String], "やられたあとも、やり直す")
	# F2 で止めたら、周回もやめる
	player.vitals.reset()
	player.vitals.take_damage(100000.0)
	pilot.enabled = false
	loop.tick(100.0)
	t.check_eq(restarts.size(), 2, "自動戦闘を止めたら、やり直さない")
	Autopilot.runs = 0
	loop.queue_free()
	player.queue_free()
	manager.queue_free()
	await tree.process_frame


func test_autopilot_state_survives_restart() -> void:
	Autopilot.resume = {}
	Autopilot.runs = 0
	var a := Autopilot.new()
	a.save_state()
	t.check(not Autopilot.new().load_state(), "自動戦闘が切れていたなら、やり直したあとも、切れたまま")
	a.enabled = true
	a.route = Autopilot.Route.BOSS_RUSH
	a.open_chests = false
	a.auto_support = false
	a.save_state()
	var b := Autopilot.new()
	t.check(b.load_state(), "自動戦闘が入っていたなら、やり直したあとも、入っている")
	t.check(b.enabled and b.route == Autopilot.Route.BOSS_RUSH and not b.open_chests and not b.auto_support, "設定も、持ち越す")
	Autopilot.runs = 2
	t.check(b.settings_text().contains("3周目"), "何周目かが、画面に出る")
	Autopilot.resume = {}
	Autopilot.runs = 0


func test_start_loadout_changes_every_restart() -> void:
	StartLoadout.last_ids = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var previous: Array[String] = StartLoadout.roll(rng)
	var changed_count: int = 0
	for i: int in 200:
		var next: Array[String] = StartLoadout.roll(rng)
		t.check(not StartLoadout.same_set(previous, next), "やり直すと、前回と別の構成になる（%d回目）" % i)
		var skills: Array[SkillDef] = []
		for id: String in next:
			skills.append(DataDB.skill(id))
		t.check(not StartLoadout.chain_pairs(skills).is_empty(), "それでも、チェインは組める")
		previous = next
		changed_count += 1
	t.check_eq(changed_count, 200, "200回やり直した")
	StartLoadout.last_ids = []


func test_balance_log_records_run() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var log: BalanceLog = main.balance_log
	t.check(log != null, "メイン画面に、バランス記録がある")
	var player := tree.get_first_node_in_group("player") as Player
	var manager: EnemyManager = main.get_node("World/EnemyManager")
	# スキルのダメージ・使用回数
	var slime: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy and n.definition.behavior == "melee_swarm":
			slime = n
			break
	slime.take_hit(10.0, DataDB.skill("slash"))
	slime.take_hit(slime.life + 1.0, DataDB.skill("fire_bolt"))
	player.caster.cast_done.emit(1, DataDB.skill("slash"), 1, false)
	player.caster.cast_done.emit(2, DataDB.skill("shatter"), 1, true)
	# ドロップ
	var item: ItemInstance = LootRoller.new(RandomNumberGenerator.new()).roll_item(10, 2)
	main.loot_director.spawn_drop(item, player.global_position)
	main.loot_director.spawn_drop(GemInstance.new(GemInstance.Kind.SKILL, "slash"), player.global_position)
	main.loot_director.spawn_drop(25, player.global_position)
	# ボスを倒す
	var boss: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy and n.definition.is_boss:
			boss = n
	boss.state = Enemy.State.CHASING
	log.tick(1.0)
	log._poll_boss()
	log.tick(20.0)
	boss.take_hit(boss.life + 1.0, DataDB.skill("slash"))
	var record: Dictionary = log.build_record("test")
	t.check_eq(int(record["schema"]), BalanceLog.SCHEMA, "記録の版")
	t.check(record["skills"].has("slash") and int(record["skills"]["slash"]["damage"]) >= 10, "スキルごとのダメージが入る")
	t.check(record["skills"].has("fire_bolt"), "撃破した火の矢のダメージも入る")
	t.check_eq(int(record["skills"]["slash"]["casts"]), 1, "使用回数")
	t.check_eq(int(record["skills"]["shatter"]["chained_casts"]), 1, "チェインで出た回数")
	t.check_eq(int(record["chain_casts"]), 1, "チェイン数")
	t.check(int(record["drops"]["counts"]["item"]) >= 1, "装備のドロップ数（敵を倒したぶんも入る）")
	t.check(int(record["drops"]["counts"]["skill_gem"]) >= 1, "スキルジェムのドロップ数")
	t.check(int(record["drops"]["currency"]) >= 25, "通貨のドロップ量")
	t.check(not (record["drops"]["items_by_rarity"] as Dictionary).is_empty(), "装備のレアリティの数")
	t.check(bool(record["boss"]["killed"]) and float(record["boss"]["kill_seconds"]) >= 20.0, "ボスの討伐の速さ")
	t.check(record["boss"].has("fight_seconds") and record["boss"].has("wake_seconds"), "ボスが動き出してから倒すまで")
	t.check(float(record["max_dps"]) >= 0.0 and record.has("avg_dps"), "最大DPS・平均DPS")
	t.check(record["start_loadout"].size() == 3 and record["final_loadout"].size() == 3, "スタートと最後のスキル構成")
	t.check(record.has("final_equipment"), "最終装備")
	# 装備を着替えると、最終装備に出る
	main.stash.collect(item)
	record = log.build_record("test")
	t.check((record["final_equipment"] as Array).size() >= 1, "最終装備に、着た装備が入る")
	t.check(record["final_equipment"][0].has("stats") and record["final_equipment"][0].has("rarity"), "装備の性能とレアリティ")
	# 書き込み：1回だけ。ファイルに、1行のJSON
	var written: Dictionary = log.finish("test_end")
	t.check(not written.is_empty() and log.is_written(), "書き込む")
	t.check(log.finish("again").is_empty(), "同じプレイは、2回書かない")
	var path: String = "user://logs_tools/" + BalanceLog.FILE_NAME
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	t.check(file != null, "テストの記録は、ツール用の場所に書かれる")
	if file != null:
		var last_line: String = ""
		while not file.eof_reached():
			var line: String = file.get_line()
			if not line.is_empty():
				last_line = line
		file.close()
		var parsed: Variant = JSON.parse_string(last_line)
		t.check(parsed is Dictionary and (parsed as Dictionary)["end_reason"] == "test_end", "最後の1行が、JSONとして読める")
	main.queue_free()


func test_balance_log_records_death_cause() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var log: BalanceLog = main.balance_log
	var player := tree.get_first_node_in_group("player") as Player
	var manager: EnemyManager = main.get_node("World/EnemyManager")
	var boss: Enemy = null
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy and n.definition.is_boss:
			boss = n
	boss.state = Enemy.State.CHASING
	boss.raged = true
	player.global_position = boss.global_position + Vector2(30, 0)
	player.on_player_hit(5.0, null)  # 発信元がなくても、落ちない
	manager._hit_player(20.0, boss, "charge")
	manager._hit_player(30.0, boss, "aoe")
	player.dodged.emit()
	t.check_eq(boss.last_attack_kind, "aoe", "最後の攻撃の種類を、敵が覚える")
	player.vitals.life = 10.0
	manager._hit_player(500.0, boss, "melee")  # とどめ
	var record: Dictionary = log.finish("death")
	t.check_eq(String(record["end_reason"]), "death", "やられた記録")
	var death: Dictionary = record["death"]
	t.check_eq(String(death["killer"]["enemy"]), "rock_lord", "とどめを刺した敵")
	t.check_eq(String(death["killer"]["kind"]), "melee", "とどめの攻撃の種類")
	t.check((death["last_hits"] as Array).size() >= 3, "直近の攻撃が残る")
	t.check(bool(death["boss"]["awake"]) and bool(death["boss"]["raged"]), "ボスが動いていて、激昂していた")
	t.check(death.has("position") and death.has("enemies_within_80"), "場所と、近くの敵の数")
	t.check(float(record["damage_taken_by"].get("rock_lord:charge", 0.0)) > 0.0, "攻撃の種類ごとのダメージの内訳")
	t.check_eq(int(record["dodges"]), 1, "回避の回数")
	main.queue_free()


func test_balance_log_records_heals() -> void:
	var main: Node = await _start_main()
	var log: BalanceLog = main.balance_log
	var player := (t as SceneTree).get_first_node_in_group("player") as Player
	log.tick(12.0)
	player.vitals.life = 20.0
	player.vitals.use_heal()
	player.vitals.life = 30.0
	player.vitals.use_heal()
	var record: Dictionary = log.build_record("test")
	var heals: Dictionary = record["heals"]
	t.check_eq(int(heals["used"]), 2, "回復を使った回数")
	t.check_eq(int(heals["left"]), 1, "回復の残り")
	t.check_eq(int(heals["max"]), 3, "はじめの回数")
	t.check_eq((heals["events"] as Array).size(), 2, "使うたびの記録")
	t.check(float(heals["events"][0]["t"]) >= 12.0 and float(heals["events"][0]["life_before_ratio"]) < 0.3, "使った時刻と、使う前の体力")
	main.queue_free()


func test_chain_skill_has_flashy_effects() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	var world: Node = main.get_node("World")
	var before: int = world.get_child_count()
	player.caster.fx_parent = world
	# チェインでない発動では、派手な演出は出ない
	player.caster.cast_done.emit(1, DataDB.skill("slash"), 1, false)
	t.check_eq(world.get_child_count(), before, "ふつうの技では、演出を足さない")
	# チェインで出た技では、輪・閃光・火花・文字が出る
	player.caster.cast_done.emit(1, DataDB.skill("shatter"), 1, true)
	var added: int = world.get_child_count() - before
	t.check(added >= 4, "チェイン技で、pixelfxの絵・画面の閃光・文字が出る（%d個）" % added)
	t.check(player.caster.fx_created >= 2, "技ごとの pixelfx の絵が出る")
	var flashes: int = 0
	for child: Node in world.get_children():
		if child is ScreenFlash:
			flashes += 1
	t.check_eq(flashes, 1, "画面全体の閃光が出る")
	var texts: int = 0
	for child: Node in world.get_children():
		if child is FloatText and (child as FloatText).text.contains("チェイン"):
			texts += 1
	t.check_eq(texts, 1, "「チェイン！」の文字が出る")
	# 技の絵は、チェインのときだけ大きい
	t.check(ChainFx.BOOST_SIZE > 1.0 and player.caster._fx_boost == 1.0, "ふだんは拡大しない")
	# 文字は、時間がたてば消える
	for child: Node in world.get_children():
		if child is FloatText:
			(child as FloatText)._process(5.0)
	await tree.process_frame
	await tree.process_frame
	var left: int = 0
	for child: Node in world.get_children():
		if child is FloatText:
			left += 1
	t.check_eq(left, 0, "文字は消える")
	main.queue_free()


func test_chain_fx_sheets_are_defined_for_every_chain_result() -> void:
	for rule: ChainRule in DataDB.chains:
		var skill: SkillDef = DataDB.skill(rule.result)
		t.check(skill != null, "チェイン技 %s がある" % rule.result)
		var keys: Dictionary = SheetFx.chain_keys(skill)
		t.check((keys["target"] as Array).size() >= 2, "チェイン技 %s に、当たる場所の絵が2つ以上ある" % rule.result)
		for group: String in ["origin", "target"]:
			for key: Variant in keys[group]:
				var def: Dictionary = SheetFx.def_of(str(key))
				t.check(not def.is_empty() and def["frame_size"] is Vector2, "絵 %s が読み込める" % key)
	var default_keys: Dictionary = SheetFx.chain_keys(DataDB.skill("slash"))
	t.check((default_keys["target"] as Array).size() >= 1, "指定のない技にも、既定の絵がある")


func test_mana_costs_and_regen() -> void:
	var player := Player.new()
	var loadout: SkillLoadout = player.caster.loadout
	loadout.set_skill(1, "slash")
	loadout.set_skill(2, "fire_bolt")
	t.check_eq(player.vitals.mana, 100.0, "マナは、はじめ満タン（100）")
	t.check_eq(player.caster.mana_cost(1), 3.0, "払いのコスト")
	t.check_eq(player.caster.mana_cost(2), 5.0, "火球のコスト")
	loadout.set_support(2, "scatter")
	t.check(absf(player.caster.mana_cost(2) - 6.5) < 0.001, "補助ジェムで、コストが増える（拡散は×1.3）")
	# 払う・足りない
	t.check(player.vitals.spend_mana(40.0), "払える")
	t.check_eq(player.vitals.mana, 60.0, "マナが減る")
	t.check(not player.vitals.spend_mana(100.0), "足りないと、払えない")
	t.check_eq(player.vitals.mana, 60.0, "足りないときは、減らない")
	# 回復
	player.vitals.tick(1.0)
	t.check_eq(player.vitals.mana, 82.0, "1秒で22回復")
	player.vitals.tick(10.0)
	t.check_eq(player.vitals.mana, 100.0, "最大を超えない")
	# 装備で最大・回復が増える
	player.vitals.stats.add("mana", 40.0)
	player.vitals.stats.add("mana_regen", 8.0)
	t.check_eq(player.vitals.max_mana(), 140.0, "装備で最大マナが増える")
	t.check_eq(player.vitals.mana_regen(), 30.0, "装備で回復が増える")
	player.free()


func test_skill_needs_mana_and_autopilot_is_mana_aware() -> void:
	var player := Player.new()
	var pilot := Autopilot.new()
	var shorts: Array[String] = []
	player.mana_short.connect(func(skill: SkillDef) -> void: shorts.append(skill.id))
	player.caster.loadout.set_skill(1, "ground_slam")
	player.caster.loadout.set_skill(2, "slash")
	player.caster.loadout.set_skill(3, "fire_bolt")
	player.vitals.mana = 2.0
	t.check(not player.use_skill(1, Vector2(100, 0)), "マナが足りないと、スキルが出ない")
	t.check_eq(shorts, ["ground_slam"] as Array[String], "マナ不足の知らせが出る")
	t.check_eq(player.caster.cooldown_left(1), 0.0, "出せなかったときは、再使用時間も始まらない")
	# 自動戦闘は、払えるものだけを、マナあたりのダメージが大きい順に出す
	player.vitals.mana = 9.0
	var slots: Array[int] = pilot.skills_to_cast(player)
	t.check(not slots.has(1) or player.caster.mana_cost(1) <= 9.0, "払えないスキルは出さない")
	var total: float = 0.0
	for slot: int in slots:
		total += player.caster.mana_cost(slot)
	t.check(total <= 9.0 + 0.001, "合計が、いまのマナの範囲に収まる")
	t.check(slots.size() >= 1, "払えるものは出す")
	player.vitals.mana = 100.0
	t.check_eq(pilot.skills_to_cast(player).size(), 3, "マナが十分なら、出せるものを全部")
	player.free()


func test_chain_aftershock_hits_enemies_where_the_effect_appears() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var player := tree.get_first_node_in_group("player") as Player
	for n: Node in tree.get_nodes_in_group("enemies"):
		if n is Enemy:
			n.hide()
			n.active = false
	var manager: EnemyManager = main.get_node("World/EnemyManager")
	var far: Vector2 = player.global_position + Vector2(300, 0)  # 足元の円（半径〜60）も、近接の範囲も、届かない場所
	var victim: Enemy = manager.spawn(DataDB.enemy("brute"), far)
	var bystander: Enemy = manager.spawn(DataDB.enemy("brute"), far + Vector2(200, 0))  # 絵の場所から、離れた敵
	var before: float = victim.life
	player.caster.fx_parent = main.get_node("World")
	var shatter: SkillDef = DataDB.skill("shatter")
	var hits: int = player.caster.aftershock(shatter, far)
	t.check_eq(hits, 1, "絵の出た場所の敵に、追加のダメージが当たる")
	t.check(victim.life < before, "敵の体力が減る")
	var dealt: float = before - victim.life
	t.check(dealt <= shatter.damage_max * CombatConsts.CHAIN_AFTERSHOCK_RATIO * 3.0, "追加のダメージは、その技の半分ていど（桁が違わない）")
	t.check_eq(bystander.life, bystander.definition.life, "離れた敵には、当たらない")
	# チェインで出たときだけ、予約される（ふつうの技では、起きない）
	var calls: Array[int] = [0]
	player.caster.cast_done.connect(func(_s: int, _k: SkillDef, _h: int, chained: bool) -> void:
		if chained:
			calls[0] += 1)
	player.caster.loadout.set_skill(1, "frost_bloom")
	player.caster.loadout.set_skill(2, "slash")
	player.caster.cast(1, far, player.global_position)
	player.caster.cast(2, far, player.global_position)
	t.check_eq(calls[0], 1, "霜囲い→払いで、砕氷が出る")
	var before2: float = victim.life
	for i: int in 20:
		await tree.physics_frame
	t.check(victim.life < before2, "チェインのあと、少し遅れて、絵の場所の敵に追加のダメージが入る")
	main.queue_free()


func test_legend_chest_is_rare_and_drops_legend() -> void:
	var main_script: GDScript = load("res://scripts/main/main.gd")
	t.check(main_script.LEGEND_CHEST_CHANCE > 0.0 and main_script.LEGEND_CHEST_CHANCE <= 0.05, "レジェンドの宝箱は、超低確率（5%以下）")
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var spots: Array = main.map.markers.get("L", [])
	t.check(spots.size() >= 3, "マップに、レジェンドの宝箱の候補の印（L）が、いくつかある")
	for spot: Vector2 in spots:
		t.check(main.map.is_floor_at(spot, true), "候補は、床の上（壁ぎわでない）")
	var chests_before: int = tree.get_nodes_in_group("chests").size()
	var chest: TreasureChest = main._place_legend_chest(true)
	t.check(chest != null and chest.legend, "置くと、レジェンドの宝箱ができる")
	t.check_eq(tree.get_nodes_in_group("chests").size(), chests_before + 1, "宝箱の仲間に入る（自動戦闘も、開けに行ける）")
	var director: LootDirector = main.loot_director
	var drops: Array[Variant] = []
	director.dropped.connect(func(value: Variant) -> void: drops.append(value))
	chest.open()
	var top_tier: int = -1
	var items: int = 0
	for value: Variant in drops:
		if value is ItemInstance:
			items += 1
			top_tier = maxi(top_tier, (value as ItemInstance).rarity.tier)
	t.check(items >= 2, "装備が、まとまって出る（%d個）" % items)
	t.check(top_tier >= 4, "かならず、レジェンド以上の装備が出る（最高の段階 %d）" % top_tier)
	chest.open()
	t.check(chest.is_open, "開いた")
	main.queue_free()
	# 抽選：ほとんどのプレイでは、置かれない
	var placed: int = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i: int in 2000:
		if rng.randf() < main_script.LEGEND_CHEST_CHANCE:
			placed += 1
	t.check(placed < 120, "2000回のうち、置かれるのは、ごくわずか（%d回）" % placed)


# ---- スキルツリー ----

func _near(a: float, b: float, eps: float, msg: String) -> void:
	t.check(absf(a - b) <= eps, "%s（実際: %s / 期待: %s）" % [msg, str(a), str(b)])


func _take_all(skill_tree: SkillTree, vitals: PlayerVitals, ids: Array) -> void:
	vitals.points = 99
	for id: String in ids:
		skill_tree.take(id, vitals)


func test_skill_tree_data_is_valid_and_connected() -> void:
	(t.root.get_node("DataDB") as Node).call("reload")
	t.check(DataDB.errors.is_empty(), "データの読み込みに間違いがない: %s" % str(DataDB.errors))
	t.check(DataDB.tree_nodes.size() >= 40, "ノードが40個以上ある（%d個）" % DataDB.tree_nodes.size())
	var starts: Array[String] = []
	var kinds: Dictionary = {}
	for node: TreeNodeDef in DataDB.tree_nodes.values():
		kinds[node.kind] = int(kinds.get(node.kind, 0)) + 1
		if node.start:
			starts.append(node.id)
	t.check_eq(starts.size(), 1, "最初のノード（根源）は1つ")
	t.check(kinds.has("small") and kinds.has("notable") and kinds.has("keystone"), "小・中・大ノードが、すべてある")
	# 根源から、全部のノードにたどり着ける
	var seen: Dictionary = {starts[0]: true}
	var queue: Array[String] = [starts[0]]
	while not queue.is_empty():
		var id: String = queue.pop_back()
		for other: TreeNodeDef in DataDB.tree_nodes.values():
			if not seen.has(other.id) and (other.links.has(id) or (DataDB.tree_node(id) as TreeNodeDef).links.has(other.id)):
				seen[other.id] = true
				queue.append(other.id)
	t.check_eq(seen.size(), DataDB.tree_nodes.size(), "すべてのノードが、根源からつながっている")
	# 大ノードは、強い代わりに縛り（マイナスの効果）がある
	for node: TreeNodeDef in DataDB.tree_nodes.values():
		if node.kind == "keystone":
			var has_penalty: bool = false
			for key: String in node.effects:
				if float(node.effects[key]) < 0.0 or (key == "mana_cost_pct" and float(node.effects[key]) > 0.0):
					has_penalty = true
			t.check(has_penalty, "大ノード %s には、縛りがある" % node.id)
	# 壊れたデータは、間違いとして報告される
	var errors: Array[String] = []
	TreeNodeDef.from_dict({"id": "x", "kind": "huge", "effects": {"nope": 1}}, errors)
	t.check(errors.size() >= 2, "存在しない種類・ステータスは、間違いになる")


func test_skill_tree_take_rules() -> void:
	(t.root.get_node("DataDB") as Node).call("reload")
	var skill_tree := SkillTree.new()
	var vitals := PlayerVitals.new()
	t.check(skill_tree.is_taken("root"), "根源は、最初から取ってある")
	t.check_eq(skill_tree.taken_count(), 0, "ポイントを使って取った数は 0")
	vitals.points = 5
	t.check(not skill_tree.take("pow_2", vitals), "つながっていないノードは、取れない")
	t.check_eq(vitals.points, 5, "取れなければ、ポイントは減らない")
	t.check(skill_tree.take("pow_1", vitals), "根源とつながるノードは、取れる")
	t.check_eq(vitals.points, 4, "ポイントが、コストぶん減る")
	t.check(not skill_tree.take("pow_1", vitals), "同じノードは、2回取れない")
	t.check(skill_tree.take("pow_2", vitals), "つながったので取れる")
	vitals.points = 1
	t.check(not skill_tree.take("pow_3", vitals), "中ノード（コスト2）は、ポイントが足りないと取れない")
	vitals.points = 2
	t.check(skill_tree.take("pow_3", vitals), "足りれば取れる")
	t.check_eq(vitals.points, 0, "ポイントを使い切った")
	t.check_eq(skill_tree.spent_points(), 4, "使ったポイントは 1+1+2")
	_near(skill_tree.stats().get_value("damage_pct"), 25.0, 0.001, "効果が足し合わさる（5+5+15）")
	# 自動取得：大ノードは取らない
	var auto_tree := SkillTree.new()
	var auto_vitals := PlayerVitals.new()
	auto_vitals.points = 1
	t.check_eq(auto_tree.auto_take(auto_vitals), 1, "自動取得：1ポイントで小ノードを1つ")
	auto_vitals.points = 200
	auto_tree.auto_take(auto_vitals)
	for id: String in auto_tree.taken_ids():
		t.check((DataDB.tree_node(id) as TreeNodeDef).kind != "keystone", "自動取得は、大ノードを取らない")
	t.check(auto_tree.taken_count() >= 30, "取れるだけ取った（%d個）" % auto_tree.taken_count())


func test_tree_effects_reach_damage_mana_and_chain() -> void:
	var main: Node = await _start_main()
	var player: Player = main.player
	var caster: SkillCaster = player.caster
	var skill_tree: SkillTree = main.skill_tree
	t.check(skill_tree != null and main.tree_screen != null, "メイン画面に、ツリーとツリー画面がある")
	var cost_before: float = caster.mana_cost(1)
	var fire: SkillDef = DataDB.skill("fire_bolt")
	var base_damage: float = DamageCalc.skill_damage(fire, caster.stats, 100.0)
	_take_all(skill_tree, player.vitals, ["pow_1", "pow_2", "proj_1", "mana_1", "mana_2", "mana_3", "mana_4", "chain_1", "sup_1"])
	_near(caster.stats.get_value("damage_pct"), 10.0, 0.001, "ツリーの効果が、プレイヤーのステータスに入る")
	_near(caster.stats.get_value("projectile_damage_pct"), 8.0, 0.001, "飛び道具のダメージ%も入る")
	_near(DamageCalc.skill_damage(fire, caster.stats, 100.0), base_damage * 1.18, 0.5, "火球のダメージが +10% +8%（飛び道具）になる")
	t.check(DamageCalc.skill_damage(DataDB.skill("slash"), caster.stats, 100.0) < DamageCalc.skill_damage(fire, caster.stats, 100.0), "近接技には、飛び道具のぶんは効かない")
	t.check(caster.mana_cost(1) <= cost_before * 0.95, "マナ消費が下がる（省マナ）")
	t.check(player.vitals.max_mana() > PlayerConsts.BASE_MAX_MANA + 40.0, "最大マナが増える")
	_take_all(skill_tree, player.vitals, ["mana_5", "key_mana"])
	t.check(caster.stats.get_value("mana_cost_pct") > -20.0, "（大ノードの縛りで、マナ消費は戻る）")
	caster.stats.add("mana_cost_pct", -500.0)
	var skill_id: String = caster.loadout.skill_id(1)
	t.check(caster.mana_cost(1) >= DataDB.skill(skill_id).mana_cost * SkillCaster.MANA_COST_MIN_RATIO - 0.001, "マナ消費は下がりすぎない（下限）")
	main.queue_free()


func test_skill_tree_screen_opens_pauses_and_takes() -> void:
	var main: Node = await _start_main()
	var tree: SceneTree = t
	var screen: SkillTreeScreen = main.tree_screen
	t.check(InputMap.has_action("toggle_skill_tree"), "ツリーを開く操作（T）が登録されている")
	t.check(not screen.is_open() and not tree.paused, "最初は閉じている")
	screen.open()
	t.check(screen.is_open() and tree.paused, "開くと、ゲームが止まる")
	main.player.vitals.points = 3
	var node: TreeNodeDef = DataDB.tree_node("pow_1")
	t.check_eq(screen.node_at(SkillTreeScreen.node_position(node)), "pow_1", "ノードの位置を指すと、そのノードが選ばれる")
	t.check_eq(screen.node_state("pow_1"), SkillTreeScreen.State.AVAILABLE, "取れるノードの状態")
	t.check_eq(screen.node_state("pow_3"), SkillTreeScreen.State.LOCKED, "つながっていないノードの状態")
	t.check(screen.take("pow_1"), "画面から取れる")
	t.check_eq(screen.node_state("pow_1"), SkillTreeScreen.State.TAKEN, "取ったノードの状態")
	t.check(screen.detail_text("pow_1").contains("取得済み"), "説明に状態が出る")
	screen.close()
	t.check(not tree.paused, "閉じると、動き出す")
	main.queue_free()


func test_autopilot_spends_tree_points_by_itself() -> void:
	var main: Node = await _start_main()
	var vitals: PlayerVitals = main.player.vitals
	main.set_autopilot(false)
	vitals.grant_xp(2000)
	t.check(vitals.points > 0 and main.skill_tree.taken_count() == 0, "手で遊ぶときは、ポイントは貯まるだけ（自分で選ぶ）")
	main.set_autopilot(true)
	t.check(main.skill_tree.taken_count() > 0, "自動戦闘を入れると、貯まったポイントを使う")
	var before: int = main.skill_tree.taken_count()
	vitals.grant_xp(5000)
	t.check(main.skill_tree.taken_count() > before, "自動戦闘中は、レベルアップのたびに使う")
	main.set_autopilot(false)
	Autopilot.resume = {}
	Autopilot.runs = 0
	main.queue_free()


# ---- リセットと、引き継いでリスタート ----

func test_restart_modes_are_wired() -> void:
	t.check(InputMap.has_action("restart_game") and InputMap.has_action("restart_carry"), "リセット(F5)と引き継ぎ(F9)の操作がある")
	var listener := RestartListener.new()
	t.check(listener.has_method("restart"), "RestartListener.restart(mode) がある")
	listener.free()
	t.check(RunCarry.Mode.RESET != RunCarry.Mode.CARRY, "2種類のモード")
	var loop := AutoLoop.new()
	t.check_eq(loop.restart_mode, RunCarry.Mode.RESET, "自動周回の標準は、これまでどおりリセット")
	loop.free()


func test_reset_discards_everything_and_carry_keeps_growth() -> void:
	RunCarry.clear()
	var main: Node = await _start_main()
	var player: Player = main.player
	var vitals: PlayerVitals = player.vitals
	var item: ItemInstance = LootRoller.new(RandomNumberGenerator.new()).roll_item(10, 2)
	main.stash.collect(item)
	main.stash.collect(GemInstance.new(GemInstance.Kind.SKILL, "ground_slam"))
	main.stash.currency = 77
	vitals.grant_xp(900)
	var level: int = vitals.level
	var xp: int = vitals.xp
	t.check(level > 1 and vitals.points > 0, "レベルが上がって、ポイントが貯まった")
	_take_all(main.skill_tree, vitals, ["pow_1", "pow_2", "vit_1"])
	vitals.points = 4
	vitals.heal_charges = 0
	var slot: String = item.base.slot

	# 引き継ぎ
	main.stash.add_gem(GemInstance.new(GemInstance.Kind.SKILL, "ground_slam"))
	main.stash.currency = 40
	vitals.heal_charges = 1
	main.player.caster.loadout.set_skill(3, "ground_slam")
	main.player.caster.loadout.set_support(3, "heavy_blow")
	var skills_before: Array[String] = []
	for k: int in range(1, SkillLoadout.SLOT_COUNT + 1):
		skills_before.append(main.player.caster.loadout.skill_id(k))
	RunCarry.prepare(RunCarry.Mode.CARRY, vitals, main.stash, main.skill_tree, main.player.caster.loadout)
	t.check_eq(RunCarry.carry_depth, 1, "引き継ぎの回数が数えられる")
	main.free()
	var carried: Node = await _start_main()
	t.check(carried.carried_over, "引き継いで始まった")
	var v2: PlayerVitals = carried.player.vitals
	t.check_eq(v2.level, level, "レベルを引き継ぐ")
	t.check_eq(v2.xp, xp, "経験値を引き継ぐ")
	t.check_eq(v2.points, 4, "使っていないポイントを引き継ぐ")
	t.check(carried.skill_tree.is_taken("pow_2") and carried.skill_tree.is_taken("vit_1"), "ツリーで取ったノードを引き継ぐ")
	t.check_eq(carried.skill_tree.taken_count(), 3, "取った数も同じ")
	t.check(carried.stash.equipment.has(slot) and carried.stash.equipment[slot] == item, "装備を引き継ぐ")
	t.check(carried.player.caster.stats.get_value("damage_pct") >= 10.0, "ツリーと装備の効果が、ステータスに戻っている")
	_near(v2.life, v2.max_life(), 0.01, "ライフは満タンで始まる")
	t.check(carried.stash.has_gem(GemInstance.Kind.SKILL, "ground_slam"), "拾ったジェムを引き継ぐ")
	t.check_eq(carried.stash.currency, 40, "通貨を引き継ぐ")
	t.check_eq(v2.heal_charges, 1, "回復の残り回数を引き継ぐ")
	for k: int in range(1, SkillLoadout.SLOT_COUNT + 1):
		t.check_eq(carried.player.caster.loadout.skill_id(k), skills_before[k - 1], "枠 %d のスキルを引き継ぐ（ランダムにしない）" % k)
	t.check_eq(carried.player.caster.loadout.support_id(3), "heavy_blow", "補助ジェムも引き継ぐ")
	t.check_eq(RunCarry.mode_name(RunCarry.last_mode), "carry", "記録用のモード名")
	var record: Dictionary = carried.balance_log.build_record("quit")
	t.check_eq(record["restart"]["mode"], "carry", "バランス記録に、引き継ぎと書かれる")
	t.check_eq(record["restart"]["start_level"], level, "バランス記録に、始めたときのレベル")
	t.check_eq(record["restart"]["carry_depth"], 1, "バランス記録に、引き継ぎの回数")
	t.check_eq((record["tree"]["taken"] as Array).size(), 3, "バランス記録に、ツリーで取ったノード")
	t.check_eq(record["tree"]["points_left"], 4, "バランス記録に、余ったポイント")

	# リセット
	RunCarry.prepare(RunCarry.Mode.RESET, v2, carried.stash, carried.skill_tree)
	t.check_eq(RunCarry.carry_depth, 0, "リセットで、引き継ぎの回数は 0 に戻る")
	carried.free()
	var fresh: Node = await _start_main()
	t.check(not fresh.carried_over, "リセットで始まった")
	t.check_eq(fresh.player.vitals.level, 1, "レベルは 1 から")
	t.check_eq(fresh.player.vitals.points, 0, "ポイントは 0 から")
	t.check_eq(fresh.skill_tree.taken_count(), 0, "ツリーは何も取っていない")
	t.check(fresh.stash.equipment.is_empty(), "装備はなし")
	var record2: Dictionary = fresh.balance_log.build_record("quit")
	t.check_eq(record2["restart"]["mode"], "reset", "バランス記録に、リセットと書かれる")
	fresh.queue_free()
	RunCarry.clear()


func test_carry_with_nothing_to_carry_and_stale_ids() -> void:
	RunCarry.clear()
	var vitals := PlayerVitals.new()
	var stash := Stash.new()
	var skill_tree := SkillTree.new()
	t.check(not RunCarry.apply(vitals, stash, skill_tree), "預かったものがなければ、何もしない")
	RunCarry.pending = {"level": 5, "xp": 3, "points": 2, "tree": ["pow_1", "no_such_node"], "equipment": {}}
	t.check(RunCarry.apply(vitals, stash, skill_tree), "預かったものを戻す")
	t.check(skill_tree.is_taken("pow_1") and not skill_tree.is_taken("no_such_node"), "存在しないノードのidは無視する")
	t.check(RunCarry.pending.is_empty(), "戻したら、預かりは空になる（次のリセットに残らない）")
	RunCarry.clear()


func test_tree_nodes_only_use_stats_the_game_reads() -> void:
	var working: PackedStringArray = ["life", "armor", "damage_pct", "fire_damage_pct", "cold_damage_pct", "lightning_damage_pct", "mana", "mana_regen",
		"melee_damage_pct", "projectile_damage_pct", "area_damage_pct", "supported_damage_pct", "chain_damage_pct", "mana_cost_pct"]
	for node: TreeNodeDef in DataDB.tree_nodes.values():
		for key: String in node.effects:
			t.check(working.has(key), "ノード %s の %s は、ゲームが読むステータス" % [node.id, key])


func test_rare_skill_has_multiple_support_slots() -> void:
	var rares: Array[SkillDef] = DataDB.rare_skills()
	t.check(rares.size() >= 3, "レアスキルが3つ以上ある")
	for skill: SkillDef in rares:
		t.check(skill.support_slots >= 2 and skill.support_slots <= 3, "%s は補助ジェムを2〜3個はめられる" % skill.id)
		t.check(not DataDB.droppable_skills().has(skill), "%s は、スタート構成の候補に入らない" % skill.id)
	var player := Player.new()
	var loadout: SkillLoadout = player.caster.loadout
	loadout.set_skill(1, "slash")
	t.check_eq(loadout.support_capacity(1), 1, "ふつうのスキルの穴は1つ")
	t.check(loadout.set_support(1, "heavy_blow"), "1つ目ははめられる")
	t.check(not loadout.set_support(1, "rapid_cast", 1), "ふつうのスキルに、2つ目はない")
	loadout.set_skill(2, "starfall")
	t.check_eq(loadout.support_capacity(2), 3, "星落としの穴は3つ")
	t.check(loadout.set_support(2, "wide_area", 0), "穴1")
	t.check(loadout.set_support(2, "heavy_blow", 1), "穴2")
	t.check(loadout.set_support(2, "burst_on_kill", 2), "穴3")
	t.check(not loadout.set_support(2, "heavy_blow", 2), "同じ補助ジェムは、同じ枠に2つはめられない")
	t.check_eq(loadout.supports(2).size(), 3, "3つはまっている")
	# 効果は合わさる：ダメージ 0.9×1.45、マナ 1.1×1.2×1.15
	var mods: Dictionary = player.caster.support_mods(2)
	t.check(absf(float(mods["damage_mult"]) - 0.9 * 1.45) < 0.001, "ダメージの倍率は掛け合わさる")
	var base_cost: float = DataDB.skill("starfall").mana_cost
	t.check(absf(player.caster.mana_cost(2) - base_cost * 1.1 * 1.2 * 1.15) < 0.01, "マナの倍率も掛け合わさる")
	# 穴が少ないスキルに替えると、余った補助ジェムは外れる
	loadout.set_skill(2, "grave_cleave")
	t.check_eq(loadout.support_id(2, 2), "", "穴を超えた分は外れる")
	loadout.set_skill(2, "slash")
	t.check_eq(loadout.support_id(2, 1), "", "ふつうのスキルに替えると、1つだけ残る")
	# 引き継ぎ（保存した形で戻せる）
	loadout.set_skill(3, "glacial_pulse")
	loadout.set_support(3, "heavy_blow", 0)
	loadout.set_support(3, "wide_area", 1)
	var vitals := PlayerVitals.new()
	RunCarry.prepare(RunCarry.Mode.CARRY, vitals, Stash.new(), null, loadout)
	var fresh := SkillLoadout.new()
	RunCarry.apply(vitals, Stash.new(), null, fresh)
	t.check_eq(fresh.skill_id(3), "glacial_pulse", "レアスキルを引き継ぐ")
	t.check_eq(fresh.support_id(3, 0), "heavy_blow", "穴1の補助を引き継ぐ")
	t.check_eq(fresh.support_id(3, 1), "wide_area", "穴2の補助を引き継ぐ")
	RunCarry.clear()
	player.free()


func test_rare_skill_gems_drop_rarely() -> void:
	t.check(LootRoller.RARE_SKILL_CHANCE > 0.0 and LootRoller.RARE_SKILL_CHANCE <= 0.1, "レアスキルは超低確率")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var roller := LootRoller.new(rng)
	var rare_ids: Array[String] = []
	for skill: SkillDef in DataDB.rare_skills():
		rare_ids.append(skill.id)
	var rare_count: int = 0
	var total: int = 4000
	for i: int in total:
		var gem: GemInstance = roller._roll_gem()
		if gem.kind == GemInstance.Kind.SKILL and rare_ids.has(gem.id):
			rare_count += 1
	t.check(rare_count > 0, "ときどき落ちる（%d / %d）" % [rare_count, total])
	t.check(float(rare_count) / float(total) < 0.1, "ほとんどは、ふつうのジェム")


func test_controller_bindings_and_tree_cursor() -> void:
	for action: String in ["move_up", "move_down", "move_left", "move_right", "dodge", "heal", "skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6", "toggle_skill_screen", "toggle_equip_screen", "toggle_skill_tree", "toggle_autobattle"]:
		var has_pad: bool = InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		t.check(has_pad, "%s にコントローラーの割り当てがある" % action)
	var has_keys: bool = InputMap.action_get_events("move_up").any(func(e: InputEvent) -> bool: return e is InputEventKey)
	t.check(has_keys, "キーボードの割り当ても残っている")
	var main: Node = await _start_main()
	var screen: SkillTreeScreen = main.tree_screen
	screen.open()
	t.check(screen.move_cursor(Vector2.RIGHT) or screen.move_cursor(Vector2.DOWN), "最初のカーソルが、根源に置かれる")
	var start_id: String = screen.hover_id
	var moved: bool = false
	for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		if screen.move_cursor(dir):
			moved = true
			break
	t.check(moved and screen.hover_id != "", "十字キーで、ほかのノードへ動かせる（%s → %s）" % [start_id, screen.hover_id])
	screen.close()
	var skills: SkillScreen = main.get_node("SkillScreen")
	skills.open()
	await t.process_frame
	t.check(skills.get_viewport().gui_get_focus_owner() != null, "スキル装備画面を開くと、どこかの欄が選ばれている")
	skills.close()
	main.queue_free()
