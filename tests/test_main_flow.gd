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


func test_movement_follows_the_floor_axes() -> void:
	# 床のマスの向き：D=右下、A=左上、W=右上、S=左下（画面の斜め）
	var east := Player.velocity_for(Vector2(1, 0))
	t.check(east.x > 0.0 and east.y > 0.0 and is_equal_approx(east.y, east.x * 0.5), "D は右下（床の軸に沿う）")
	var north := Player.velocity_for(Vector2(0, -1))
	t.check(north.x > 0.0 and north.y < 0.0 and is_equal_approx(-north.y, north.x * 0.5), "W は右上")
	var west := Player.velocity_for(Vector2(-1, 0))
	t.check(west.x < 0.0 and west.y < 0.0, "A は左上")
	var south := Player.velocity_for(Vector2(0, 1))
	t.check(south.x < 0.0 and south.y > 0.0, "S は左下")
	# 2つ押すと、画面の上下左右
	t.check_eq(snappedf(Player.velocity_for(Vector2(1, -1).normalized()).y, 0.001), 0.0, "W+D は真横（右）")
	t.check(Player.velocity_for(Vector2(1, -1).normalized()).x > 0.0, "W+D は右向き")
	t.check_eq(snappedf(Player.velocity_for(Vector2(1, 1).normalized()).x, 0.001), 0.0, "S+D は真下")
	# 地面の上での速さは、どの向きでも同じ
	var base := Iso.ground_distance(Vector2.ZERO, Player.velocity_for(Vector2(1, 0)))
	for key: Vector2 in [Vector2(0, -1), Vector2(-1, 0), Vector2(0, 1), Vector2(1, -1).normalized(), Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(-1, -1).normalized()]:
		t.check(absf(Iso.ground_distance(Vector2.ZERO, Player.velocity_for(key)) - base) < 0.01, "地面の速さが同じ: %s" % str(key))
	t.check(absf(base - Player.MOVE_SPEED) < 0.01, "地面の速さは MOVE_SPEED")


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
	var edge_pos: Vector2 = map.floor_layer.map_to_local(Vector2i(1, 1))
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
	t.check_eq(chests.size(), 1, "最初の広場に宝箱が1つある")
	if chests.is_empty():
		main.queue_free()
		return
	var chest := chests[0] as TreasureChest
	var player := tree.get_first_node_in_group("player") as Player
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
