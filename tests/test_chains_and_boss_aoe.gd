extends RefCounted
## 新しいチェイン（焔突き・雷落とし・溶岩玉・湯気爆ぜ）と、ボスの範囲攻撃

var t: Variant


func _db() -> Node:
	var db: Node = (Engine.get_main_loop() as SceneTree).root.get_node("DataDB")
	db.reload()
	return db


func _chain(db: Node, first: String, second: String) -> String:
	var tr := ChainTracker.new()
	tr.on_cast(db.skill(first), db.chains, db.skills)
	return tr.on_cast(db.skill(second), db.chains, db.skills).id


func test_every_chain_triggers_from_its_own_sequence() -> void:
	var db := _db()
	t.check_eq(_chain(db, "frost_bloom", "slash"), "shatter", "霜囲い→払い太刀＝砕氷（そのまま）")
	t.check_eq(_chain(db, "fire_ring", "slash"), "blaze_thrust", "ほむら輪→払い太刀＝焔突き")
	t.check_eq(_chain(db, "fire_ring", "thrust"), "blaze_thrust", "ほむら輪→通し突き＝焔突き")
	t.check_eq(_chain(db, "spark_shot", "frost_bloom"), "thunder_fall", "稲妻針→霜囲い＝雷落とし")
	t.check_eq(_chain(db, "spark_shot", "ground_slam"), "thunder_fall", "稲妻針→地鳴らし＝雷落とし")
	t.check_eq(_chain(db, "ground_slam", "fire_bolt"), "magma_ball", "地鳴らし→火だま打ち＝溶岩玉")
	t.check_eq(_chain(db, "fire_bolt", "frost_bloom"), "steam_burst", "火だま打ち→霜囲い＝湯気爆ぜ")


func test_unrelated_sequences_do_not_chain() -> void:
	var db := _db()
	t.check_eq(_chain(db, "slash", "slash"), "slash", "払い→払いは変わらない")
	t.check_eq(_chain(db, "fire_bolt", "fire_bolt"), "fire_bolt", "火球→火球は変わらない")
	t.check_eq(_chain(db, "ice_shard", "ground_slam"), "ground_slam", "氷つぶて→地鳴らしは変わらない")


func test_chain_skills_are_chain_only_and_similar_in_power() -> void:
	var db := _db()
	var shatter: SkillDef = db.skill("shatter")
	for id: String in ["blaze_thrust", "thunder_fall", "magma_ball", "steam_burst"]:
		var s: SkillDef = db.skill(id)
		t.check(s != null and s.chain_only, "%s はチェイン専用" % id)
		t.check(not db.droppable_skills().has(s), "%s は落ちない" % id)
		# 砕氷より強すぎず、弱すぎない（平均ダメージが 0.6〜1.1 倍）
		var ratio: float = ((s.damage_min + s.damage_max) * 0.5) / ((shatter.damage_min + shatter.damage_max) * 0.5)
		t.check(ratio >= 0.6 and ratio <= 1.1, "%s の強さは砕氷の0.6〜1.1倍（実際 %.2f）" % [id, ratio])


func _boss_world() -> Array:
	var tree: SceneTree = t
	var db := _db()
	var world := Node2D.new()
	tree.root.add_child(world)
	var manager := EnemyManager.new()
	manager.enemy_parent = world
	world.add_child(manager)
	var boss: Enemy = manager.spawn(db.enemy("rock_lord"), Vector2.ZERO)
	boss.state = Enemy.State.CHASING
	return [world, manager, boss]


func _run(manager: EnemyManager, boss: Enemy, target: Vector2, seconds: float) -> Dictionary:
	var result := {"aoe": 0, "telegraph": 0, "burst": 0, "melee": 0}
	var def: EnemyDef = boss.definition
	manager.player_hit.connect(func(damage: float, _src: Enemy) -> void:
		if is_equal_approx(damage, def.aoe_damage):
			result["aoe"] += 1
		else:
			result["melee"] += 1)
	manager.aoe_telegraph.connect(func(_e: Enemy, _r: float, _w: float) -> void: result["telegraph"] += 1)
	manager.aoe_burst.connect(func(_e: Enemy, _r: float) -> void: result["burst"] += 1)
	var elapsed := 0.0
	while elapsed < seconds:
		manager._update_enemy(boss, target, 0.05)
		boss.global_position = Vector2.ZERO  # その場に固定する（遠くのプレイヤーへ近づいて、範囲に入らないように）
		elapsed += 0.05
	return result


func test_boss_aoe_hits_inside_radius_only() -> void:
	var w := _boss_world()
	var manager: EnemyManager = w[1]
	var boss: Enemy = w[2]
	var def: EnemyDef = boss.definition
	t.check(def.aoe_radius > 0.0 and def.aoe_damage > def.damage, "ボスの範囲攻撃は、通常攻撃より重い")
	var inside := _run(manager, boss, Vector2(def.aoe_radius * 0.5, 0), def.aoe_interval + def.aoe_windup + 1.0)
	t.check(inside["telegraph"] >= 1, "予告が出る")
	t.check(inside["burst"] >= 1, "予告のあとに、範囲攻撃が起きる")
	t.check(inside["aoe"] >= 1, "範囲の中にいると、範囲攻撃のダメージが入る")
	(w[0] as Node).queue_free()

	var w2 := _boss_world()
	var m2: EnemyManager = w2[1]
	var b2: Enemy = w2[2]
	var outside := _run(m2, b2, Vector2(def.aoe_radius * 3.0, 0), def.aoe_interval + def.aoe_windup + 1.0)
	t.check(outside["burst"] >= 1, "遠くにいても、範囲攻撃は起きる")
	t.check_eq(outside["aoe"], 0, "範囲の外にいれば、当たらない")
	(w2[0] as Node).queue_free()


func test_boss_stands_still_while_telegraphing() -> void:
	var w := _boss_world()
	var manager: EnemyManager = w[1]
	var boss: Enemy = w[2]
	var def: EnemyDef = boss.definition
	boss.aoe_timer = 0.0  # すぐ予告に入る
	var target := Vector2(def.aoe_radius * 3.0, 0)
	manager._update_enemy(boss, target, 0.05)
	t.check(boss.aoe_windup_left > 0.0, "予告に入った")
	var before := boss.global_position
	for i in 10:
		manager._update_enemy(boss, target, 0.05)
	t.check(boss.global_position.is_equal_approx(before), "予告のあいだは、足を止める（避ける時間を作る）")
	(w[0] as Node).queue_free()
