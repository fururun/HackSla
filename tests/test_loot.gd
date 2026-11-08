extends RefCounted

var t: Variant


func _db() -> Node:
	var db: Node = (Engine.get_main_loop() as SceneTree).root.get_node("DataDB")
	db.reload()
	return db


func _roller(seed_value: int = 140014) -> LootRoller:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return LootRoller.new(rng)


func test_rarity_weights() -> void:
	var db: Node = _db()
	var roller: LootRoller = _roller()
	var counts: Dictionary = {}
	var total_weight: float = 0.0
	const SAMPLES: int = 10000
	for rarity: RarityDef in db.rarities:
		counts[rarity.id] = 0
		total_weight += rarity.weight
	for index: int in range(SAMPLES):
		counts[roller.roll_rarity().id] += 1
	for rarity: RarityDef in db.rarities:
		var probability: float = rarity.weight / total_weight
		var expected: float = SAMPLES * probability
		var tolerance: float = maxf(5.0 * sqrt(SAMPLES * probability * (1.0 - probability)), 5.0)
		t.check(absf(counts[rarity.id] - expected) <= tolerance, rarity.id + " の回数が weight の期待値の5標準偏差以内")
	print("[Loot 10000 seed=140014] ", counts)


func test_items_follow_data() -> void:
	var db: Node = _db()
	var roller: LootRoller = _roller()
	var saw_common: bool = false
	var seen_slots: Dictionary = {}
	for index: int in range(2000):
		var item: ItemInstance = roller.roll_item(1)
		t.check(item != null, "レベル1の装備を生成")
		if item == null:
			return
		seen_slots[item.base.slot] = true
		t.check(item.base.level <= 1, "レベル以下の土台")
		var ids: Dictionary = {}
		var eligible: int = 0
		for affix: AffixDef in db.affixes.values():
			if affix.weight > 0.0 and affix.can_roll_on(item.base.slot):
				eligible += 1
		t.check(item.affixes.size() >= mini(item.rarity.affix_min, eligible), "候補数を考慮した付与効果の下限")
		t.check(item.affixes.size() <= mini(item.rarity.affix_max, eligible), "付与効果の上限")
		for rolled: Dictionary in item.affixes:
			var affix: AffixDef = db.affixes[rolled["id"]]
			t.check(not ids.has(affix.id), "付与効果は重複しない")
			ids[affix.id] = true
			t.check(affix.can_roll_on(item.base.slot), "付与効果が部位に合う")
			t.check(rolled["value"] is int, "付与効果の値は整数")
			t.check(rolled["value"] >= affix.value_min and rolled["value"] <= affix.value_max, "値は定義の範囲内")
		if item.rarity.id == "common":
			saw_common = true
			t.check_eq(item.affixes.size(), 0, "common は付与効果なし")
	t.check(saw_common, "common の検証を実施")
	for base: ItemBaseDef in db.bases.values():
		if base.level <= 1:
			t.check(seen_slots.has(base.slot), "各部位を検証: " + base.slot)
	t.check(roller.roll_item(0) == null, "対象の土台がないレベルでは生成しない")


func test_total_stats_and_name() -> void:
	var db: Node = _db()
	var item: ItemInstance = ItemInstance.new()
	item.base = db.bases["leather_vest"]
	item.rarity = db.rarities[0]
	item.affixes = [{"id": "life_1", "value": 17}, {"id": "armor_1", "value": 9}]
	var original: Dictionary = item.base.stats.duplicate()
	var stats: Dictionary = item.total_stats()
	t.check_eq(stats["life"], original["life"] + 17, "土台と life を合計")
	t.check_eq(stats["armor"], original["armor"] + 9, "土台と armor を合計")
	stats["life"] = -1
	t.check_eq(item.base.stats, original, "集計は土台の定義を変更しない")
	t.check_eq(item.display_name(), "%s %s" % [item.rarity.name, item.base.name], "レアリティと土台の表示名")


func test_drops_and_repeatability() -> void:
	var db: Node = _db()
	var roller: LootRoller = _roller()
	var repeat: LootRoller = _roller()
	var enemy: EnemyDef = db.enemy("swarmling")
	var skills_seen: Dictionary = {}
	var supports_seen: Dictionary = {}
	var items_seen: int = 0
	var currency_seen: int = 0
	for index: int in range(2000):
		var drops: Array = roller.roll_drops(enemy, 1)
		var replay: Array = repeat.roll_drops(enemy, 1)
		t.check_eq(_signature(drops), _signature(replay), "同じ seed で装備の値まで再現")
		for drop: Variant in drops:
			if drop is GemInstance:
				var gem: GemInstance = drop
				if gem.kind == GemInstance.Kind.SKILL:
					var skill: SkillDef = db.skill(gem.id)
					t.check(skill != null and not skill.chain_only, "チェイン専用技は落ちない")
					skills_seen[gem.id] = true
				else:
					t.check(db.support(gem.id) != null, "補助ジェムの id が存在")
					supports_seen[gem.id] = true
			elif drop is ItemInstance:
				items_seen += 1
			else:
				t.check(drop is int and drop > 0, "通貨は正の整数")
				currency_seen += 1
	t.check(items_seen > 0 and currency_seen > 0, "装備と通貨が落ちる")
	for skill: SkillDef in db.droppable_skills():
		t.check(skills_seen.has(skill.id), "通常スキルが落ちる: " + skill.id)
	for support: SupportDef in db.supports.values():
		t.check(supports_seen.has(support.id), "補助ジェムが落ちる: " + support.id)
	var empty_enemy: EnemyDef = EnemyDef.new()
	t.check(roller.roll_drops(empty_enemy, 1).is_empty(), "xp 0 の敵は落とさない")
	# 装備候補のないレベルでは通貨へ回るため、合計価値で枠数の増加を確認。
	var low: EnemyDef = EnemyDef.new()
	low.xp = 1
	var high: EnemyDef = EnemyDef.new()
	high.xp = 100
	var low_total: int = 0
	var high_total: int = 0
	for index: int in range(100):
		low_total += _drop_units(roller.roll_drops(low, 0), low.xp)
		high_total += _drop_units(roller.roll_drops(high, 0), high.xp)
	t.check(high_total > low_total, "xp が大きい敵ほどドロップ枠が多い")


func test_each_rarity_and_level_gate() -> void:
	var db: Node = _db()
	var roller: LootRoller = _roller()
	var rarities: Array[RarityDef] = db.rarities.duplicate()
	var bases: Dictionary = db.bases.duplicate()
	# ごく稀なレアリティも、各部位について確実に検証する。
	for rarity: RarityDef in rarities:
		db.rarities.assign([rarity])
		for base: ItemBaseDef in bases.values():
			db.bases = {base.id: base}
			var eligible: int = 0
			for affix: AffixDef in db.affixes.values():
				if affix.weight > 0.0 and affix.can_roll_on(base.slot):
					eligible += 1
			var item: ItemInstance = roller.roll_item(base.level)
			t.check_eq(item.rarity, rarity, "指定レアリティを検証")
			t.check(item.affixes.size() >= mini(rarity.affix_min, eligible), "候補不足時も可能な数を付ける")
			t.check(item.affixes.size() <= mini(rarity.affix_max, eligible), "候補数を超えない")
	# テスト用定義で、低レベルと高レベルの土台を混在させる。
	var low: ItemBaseDef = ItemBaseDef.new()
	low.level = 1
	low.slot = "weapon"
	var high: ItemBaseDef = ItemBaseDef.new()
	high.level = 10
	high.slot = "armor"
	db.bases = {"low": low, "high": high}
	db.rarities.assign(rarities)
	for index: int in range(100):
		t.check_eq(roller.roll_item(1).base, low, "高レベルの土台を除外")
	var saw_high: bool = false
	for index: int in range(100):
		if roller.roll_item(10).base == high:
			saw_high = true
	t.check(saw_high, "必要レベル到達後は高レベルの土台も選ぶ")
	db.reload()


func _drop_units(drops: Array, xp: int) -> int:
	var units: int = 0
	for drop: Variant in drops:
		units += int(drop / (xp * LootRoller.CURRENCY_PER_XP)) if drop is int else 1
	return units


func _signature(drops: Array) -> Array:
	var result: Array = []
	for drop: Variant in drops:
		if drop is ItemInstance:
			result.append([drop.base.id, drop.rarity.id, drop.affixes])
		elif drop is GemInstance:
			result.append([drop.kind, drop.id])
		else:
			result.append(drop)
	return result

func test_unowned_gem_weight_in_roll_drops() -> void:
	var db: Node = _db()
	var owned: Dictionary = {GemInstance.Kind.SKILL: {}, GemInstance.Kind.SUPPORT: {}}
	for skill: SkillDef in db.droppable_skills():
		owned[GemInstance.Kind.SKILL][skill.id] = true
	for support: SupportDef in db.supports.values():
		owned[GemInstance.Kind.SUPPORT][support.id] = true
	owned[GemInstance.Kind.SUPPORT].erase("scatter")
	var biased: LootRoller = _roller(210021)
	var neutral: LootRoller = _roller(210021)
	var defaulted: LootRoller = _roller(210021)
	var empty: LootRoller = _roller(210021)
	var counts: Array[int] = [0, 0, 0, 0]
	for index: int in range(15000):
		var enemy: EnemyDef = db.enemy("swarmling")
		for variant: int in 2:
			var drops: Array = biased.roll_drops(enemy, 1, owned) if variant == 0 else neutral.roll_drops(enemy, 1)
			for drop: Variant in drops:
				if drop is GemInstance:
					counts[variant * 2 + 1] += 1
					if drop.kind == GemInstance.Kind.SUPPORT and drop.id == "scatter":
						counts[variant * 2] += 1
		if index < 100:
			t.check_eq(_signature(defaulted.roll_drops(enemy, 1)), _signature(empty.roll_drops(enemy, 1, {})), "省略と空集合は同一")
	var candidates: int = db.droppable_skills().size() + db.supports.size()
	var expected: float = LootRoller.GEM_NEW_WEIGHT_MULT / (candidates - 1 + LootRoller.GEM_NEW_WEIGHT_MULT)
	t.check(absf(float(counts[0]) / counts[1] - expected) < 0.05, "未所持の抽選率は4倍の重みに合う")
	t.check(float(counts[0]) / counts[1] > float(counts[2]) / counts[3] * 1.6, "省略時より未所持が出やすい")

func test_only_fixed_starting_supports() -> void:
	var db: Node = _db()
	var support: SupportDef = SupportDef.new()
	support.id = "future_support"
	db.supports[support.id] = support
	var stash: Stash = Stash.new()
	t.check(not stash.has_gem(GemInstance.Kind.SUPPORT, support.id), "追加補助は初期所持しない")
	stash.collect(GemInstance.new(GemInstance.Kind.SUPPORT, support.id))
	t.check_eq(stash.currency, 0, "初取得では通貨なし")
	stash.collect(GemInstance.new(GemInstance.Kind.SUPPORT, support.id))
	t.check_eq(stash.currency, Stash.GEM_DUPLICATE_CURRENCY, "重複補助を通貨へ")
	db.reload()
