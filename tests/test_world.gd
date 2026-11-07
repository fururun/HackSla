extends RefCounted
## 向き（8方向）、斜め視点の距離、マップの読み込み、メイン画面の起動

var t: Variant


func test_facing_8_directions() -> void:
	t.check_eq(Facing.dir8(Vector2.RIGHT), 0, "右")
	t.check_eq(Facing.dir8(Vector2(1, 1)), 1, "右下")
	t.check_eq(Facing.dir8(Vector2.DOWN), 2, "下")
	t.check_eq(Facing.dir8(Vector2.LEFT), 4, "左")
	t.check_eq(Facing.dir8(Vector2.UP), 6, "上")
	t.check_eq(Facing.dir8(Vector2(1, -1)), 7, "右上")


func test_sprite_uses_5_directions_with_mirror() -> void:
	var rows := {}
	for d in 8:
		rows[Facing.sprite_row(d)] = true
	t.check_eq(rows.size(), 5, "描く方向は5つ")
	t.check(Facing.sprite_flip(4) and not Facing.sprite_flip(0), "左は右の反転")


func test_ground_distance_is_isometric() -> void:
	t.check_eq(Iso.ground_distance(Vector2.ZERO, Vector2(20, 0)), 20.0, "横はそのまま")
	t.check_eq(Iso.ground_distance(Vector2.ZERO, Vector2(0, 10)), 20.0, "縦は2倍で測る")
	t.check(Iso.in_ground_arc(Vector2.ZERO, Vector2.RIGHT, Vector2(20, 2), 30, 60), "正面の敵に当たる")
	t.check(not Iso.in_ground_arc(Vector2.ZERO, Vector2.RIGHT, Vector2(-20, 0), 30, 60), "背後の敵には当たらない")


func test_map_markers_and_walls() -> void:
	var rows := PackedStringArray(["#####", "#P.D#", "#####", "#####"])
	t.check_eq(IsoMap._wall_kind(rows, 0, 0), IsoMap.WALL, "床が手前にある壁は高い")
	t.check_eq(IsoMap._wall_kind(rows, 2, 2), IsoMap.LOW_WALL, "床が奥にある壁は低い")
	t.check_eq(IsoMap._wall_kind(rows, 2, 3), Vector2i(-1, -1), "床に接しない壁は描かない")


func test_main_scene_runs() -> void:
	var tree: SceneTree = t
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	tree.root.add_child(main)
	for i in 10:
		await tree.process_frame
	var player := tree.get_first_node_in_group("player") as Player
	t.check(player != null, "プレイヤーがいる")
	var dummies: Array[Node2D] = []
	for node: Node in tree.get_nodes_in_group("enemies"):
		if node is TrainingDummy:
			dummies.append(node as Node2D)
	t.check_eq(dummies.size(), 2, "案山子が2体")
	t.check(tree.get_nodes_in_group("enemies").size() > 2, "マップの印から敵の群れが置かれる")
	var world_node: Node = main.get_node("World")
	var swarm_in_world := true
	for node: Node in tree.get_nodes_in_group("enemies"):
		if not node is TrainingDummy and node.get_parent() != world_node:
			swarm_in_world = false
	t.check(swarm_in_world, "敵は壁・プレイヤーと同じY軸ソートの親(World)の直下にいる")
	var dummy: Node2D = dummies[0]
	player.global_position = dummy.global_position + Vector2(-16, 4)
	t.check(player.try_basic_attack(dummy.global_position), "斬撃を出せる")
	t.check(not player.try_basic_attack(dummy.global_position), "再使用時間中は出せない")
	t.check((dummy as TrainingDummy).current_dps() > 0.0, "案山子にダメージが入る")
	main.queue_free()
	await tree.process_frame
