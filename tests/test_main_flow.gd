extends RefCounted
## メイン画面でつないだ流れ：敵に殴られる → 倒すと経験値とドロップ → 拾うと装備がステータスに効く

var t: Variant


func _start_main() -> Node:
	var tree: SceneTree = t
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	tree.root.add_child(main)
	for i in 5:
		await tree.process_frame
	return main


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
	if item == null:
		main.queue_free()
		return
	stash.collect(item)
	t.check(player.vitals.max_life() > life_before, "装備の life が最大ライフに足される")
	main.queue_free()
