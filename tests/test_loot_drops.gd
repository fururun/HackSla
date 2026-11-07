extends RefCounted
var t: Variant

func _item(slot: String, tier: int, stats: Dictionary) -> ItemInstance:
	var item: ItemInstance = ItemInstance.new()
	item.base = ItemBaseDef.new()
	item.base.slot = slot
	item.base.stats = stats
	item.rarity = RarityDef.new()
	item.rarity.tier = tier
	return item

func test_stash() -> void:
	var stash: Stash = Stash.new()
	for id: String in ["slash", "frost_bloom", "fire_bolt"]:
		t.check(stash.has_gem(GemInstance.Kind.SKILL, id), "初期スキル")
	for support: SupportDef in DataDB.supports.values():
		t.check(stash.has_gem(GemInstance.Kind.SUPPORT, support.id), "補助はデータから全て所持")
	var changes: Array[int] = [0]
	stash.changed.connect(func() -> void: changes[0] += 1)
	var gem: GemInstance = GemInstance.new(GemInstance.Kind.SKILL, "test_gem")
	stash.add_gem(gem)
	stash.add_gem(gem)
	t.check_eq(changes[0], 1, "ジェム重複では変更しない")
	t.check(not stash.has_gem(GemInstance.Kind.SUPPORT, "test_gem"), "種類別に所持")
	var low: ItemInstance = _item("weapon", 0, {"damage_pct": 2})
	var high: ItemInstance = _item("weapon", 2, {"damage_pct": 5, "life": 3})
	stash.collect(low)
	t.check_eq(stash.equipment["weapon"], low, "空き部位を装備")
	stash.collect(high)
	stash.collect(_item("weapon", 2, {"damage_pct": 99}))
	stash.collect(low)
	t.check_eq(stash.equipment["weapon"], high, "高tierだけ更新、同tierと下位は維持")
	stash.collect(_item("ring", 1, {"damage_pct": 7, "armor": 4}))
	var stats: StatBlock = stash.equipment_stats()
	t.check_eq(stats.get_value("damage_pct"), 12.0, "部位間で合算")
	t.check_eq(stats.get_value("life"), 3.0, "個別の値")
	t.check_eq(stash.equipment_stats().get_value("damage_pct"), 12.0, "繰返し計算で二重加算しない")
	stash.collect(8)
	stash.collect(4)
	t.check_eq(stash.currency, 12, "通貨を合算")

func test_equipment_affixes() -> void:
	var stash: Stash = Stash.new()
	var affix: AffixDef = DataDB.affixes.values()[0]
	var item: ItemInstance = _item("armor", 0, {affix.stat: 5})
	item.affixes.append({"id": affix.id, "value": 7})
	stash.collect(item)
	t.check_eq(stash.equipment_stats().get_value(affix.stat), 12.0, "付与効果も合算")

func test_drops_pickup_pool_and_limit() -> void:
	var world: Node2D = Node2D.new()
	var player: Node2D = Node2D.new()
	var manager: EnemyManager = EnemyManager.new()
	var director: LootDirector = LootDirector.new()
	world.add_child(player)
	world.add_child(manager)
	world.add_child(director)
	var stash: Stash = Stash.new()
	var levels: Array[int] = [0]
	director.setup(manager, player, world, stash, func() -> int: levels[0] += 1; return 1)
	var enemy: Enemy = Enemy.new()
	enemy.definition = EnemyDef.new()
	enemy.definition.xp = 20
	world.add_child(enemy)
	manager.enemy_hit.emit(enemy, 1.0, false)
	t.check_eq(director.active_count(), 0, "非撃破なら落ちない")
	t.check_eq(levels[0], 0, "非撃破ならレベルも読まない")
	enemy.definition.xp = 0
	manager.enemy_hit.emit(enemy, 1.0, true)
	t.check_eq(director.active_count(), 0, "xp0なら落ちない")
	enemy.definition.xp = 20
	manager.enemy_hit.emit(enemy, 1.0, true)
	t.check(director.active_count() > 0, "撃破の信号から生成")
	director.setup(manager, player, world, stash, func() -> int: return 1)
	var created_before: int = director.drops_created
	var gem: GemInstance = GemInstance.new(GemInstance.Kind.SKILL, "pickup_test")
	var first: GroundDrop = director.spawn_drop(gem, Vector2(0, LootDirector.PICKUP_RADIUS * 0.5 + 0.1))
	director.tick(0.0)
	t.check_eq(director.active_count(), 1, "縦距離を2倍して範囲外")
	player.position.y = 0.1
	director.tick(0.0)
	t.check(stash.has_gem(gem.kind, gem.id), "範囲境界で拾える")
	t.check_eq(director.pooled_count(), 1, "回収後プールへ")
	var reused: GroundDrop = director.spawn_drop(9, Vector2(1000, 1000))
	t.check_eq(first, reused, "同じノードを再利用")
	director.tick(LootDirector.CURRENCY_FLIGHT_TIME * 0.5)
	t.check_eq(stash.currency, 0, "通貨は短い飛行の途中")
	player.position += Vector2(20, 20)
	director.tick(LootDirector.CURRENCY_FLIGHT_TIME)
	t.check_eq(stash.currency, 9, "移動中も通貨を自動回収")
	var beamed: ItemInstance = _item("weapon", 3, {})
	beamed.rarity.beam = true
	var oldest: GroundDrop = director.spawn_drop(beamed, Vector2(100, 100))
	t.check(oldest.beam, "装備のbeamを反映")
	for index: int in LootDirector.MAX_GROUND_DROPS:
		director.spawn_drop(gem, Vector2(index + 100, 100))
	t.check_eq(director.active_count(), LootDirector.MAX_GROUND_DROPS, "地面の上限")
	t.check_eq(director.drops_created - created_before, LootDirector.MAX_GROUND_DROPS, "上限以上のノードを作らない")
	t.check_eq(oldest.value, gem, "古いものから再利用")
	t.check(not oldest.beam, "再利用時に柱をリセット")
	director.free()
	t.check_eq(world.get_child_count(), 3, "World直下のドロップも破棄")
	world.free()

func test_loot_hud() -> void:
	var tree: SceneTree = t as SceneTree
	var stash: Stash = Stash.new()
	var hud: LootHud = LootHud.new()
	hud.setup(stash)
	tree.root.add_child(hud)
	await tree.process_frame
	var rect: Rect2 = hud._currency.get_global_rect()
	t.check(rect.position.x >= 300 and rect.end.x <= 480, "HUDは画面右端の内側")
	t.check_eq(hud._currency.get_theme_font_size("font_size"), 8, "HUDの文字サイズ")
	stash.collect(5)
	t.check_eq(hud._currency.text, "通貨: 5", "通貨表示を更新")
	for index: int in 4:
		stash.collect(GemInstance.new(GemInstance.Kind.SKILL, "slash"))
	t.check_eq(hud._recent.size(), 3, "直近3行")
	t.check_eq(hud._recent[0]["text"], DataDB.skill("slash").name, "ジェムの表示名")
	hud._process(LootHud.MESSAGE_LIFETIME + 0.1)
	t.check(hud._recent.is_empty(), "数秒後に消える")
	hud.free()
