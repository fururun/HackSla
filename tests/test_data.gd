extends RefCounted
## data/ のJSONが正しく読めるか、チェインの判定が決まりどおりか

var t: Variant


func _db() -> Node:
	var db: Node = load("res://scripts/data/data_db.gd").new()
	db.reload()
	return db


func test_data_loads_without_errors() -> void:
	var db := _db()
	for e: String in db.errors:
		printerr("    データの間違い: " + e)
	t.check(db.errors.is_empty(), "data/ にエラーがない")
	t.check(db.skills.size() >= 3, "スキルが3つ以上ある")
	t.check(db.skill("shatter") != null and db.skill("shatter").chain_only, "砕氷はチェイン専用")
	t.check(not db.droppable_skills().any(func(s: SkillDef) -> bool: return s.chain_only), "チェイン専用の技はドロップしない")
	db.free()


func test_bad_data_is_reported() -> void:
	var errs: Array[String] = []
	SkillDef.from_dict({"id": "x", "element": "water", "kind": "melee", "damage": [5, 1]}, errs)
	t.check(errs.size() >= 2, "存在しない属性と、最小>最大の両方を指摘する")
	errs.clear()
	SupportDef.from_dict({"id": "y", "modifiers": {"unknown_key": 1}}, errs)
	t.check(errs.size() == 1, "使えない modifiers のキーを指摘する")


func test_chain_by_tags() -> void:
	var db := _db()
	var tr := ChainTracker.new()
	var frost: SkillDef = db.skill("frost_bloom")
	var slash: SkillDef = db.skill("slash")
	var bolt: SkillDef = db.skill("fire_bolt")

	t.check_eq(tr.on_cast(slash, db.chains, db.skills).id, "slash", "起点なしなら変化しない")
	t.check_eq(tr.on_cast(frost, db.chains, db.skills).id, "frost_bloom", "氷華はそのまま出る")
	t.check(tr.preview(slash, db.chains) == null, "未発見のチェインは光らない")
	t.check_eq(tr.on_cast(slash, db.chains, db.skills).id, "shatter", "氷華→斬撃で砕氷に変わる")
	t.check(tr.discovered.has("shatter"), "図鑑に記録される")
	t.check_eq(tr.on_cast(slash, db.chains, db.skills).id, "slash", "2段階まで：チェインの後は数え直し")

	tr.on_cast(frost, db.chains, db.skills)
	t.check(tr.preview(slash, db.chains) != null, "発見済みなら光る")
	tr.on_cast(bolt, db.chains, db.skills)
	t.check_eq(tr.on_cast(slash, db.chains, db.skills).id, "slash", "間に別のスキルを挟むと無効")
	db.free()


func test_specific_chain_wins_over_tags() -> void:
	var db := _db()
	var errs: Array[String] = []
	var special := ChainRule.from_dict({"id": "sp", "prev_skill": "frost_bloom", "next_skill": "slash", "result": "shatter"}, errs)
	var by_tag: ChainRule = db.chains[0]
	var rules: Array[ChainRule] = [by_tag, special]
	var found := ChainTracker.find_rule(db.skill("frost_bloom"), db.skill("slash"), rules)
	t.check_eq(found.id, "sp", "特定スキル指定が優先")
	db.free()


func test_text_adopted_set() -> void:
	var db := _db()
	t.check(db.errors.is_empty(), "表示名データにエラーがない")
	t.check_eq(db.skill("slash").name, "払い太刀", "暫定採用: 近接の斬撃")
	t.check_eq(db.skill("frost_bloom").name, "霜囲い", "暫定採用: 冷気の範囲攻撃")
	t.check_eq(db.skill("fire_bolt").name, "火だま打ち", "暫定採用: 火の飛び道具")
	t.check_eq(db.skill("shatter").name, "霜砕き", "暫定採用: 凍えた敵を砕く技")
	t.check_eq(db.chains[0].name, "霜砕き", "チェイン名もスキル名と揃う")
	t.check_eq(db.support("scatter").name, "三つ又", "暫定採用: 補助 3方向")
	t.check_eq(db.support("burst_on_kill").name, "はじけ仕舞い", "暫定採用: 補助 爆発")
	t.check_eq(db.enemy("swarmling").name, "スライム", "雑魚敵はスライム（ふるるん指定）")
	t.check_eq(db.enemy("brute").name, "岩のろ", "暫定採用: 岩魔物")
	t.check_eq(db.enemy("training_dummy").name, "不倒さん", "暫定採用: 的")
	t.check_eq(db.text_of("skill", "slash").reading(), "はらいたち", "読み仮名を引ける")
	t.check_eq(db.rarities[4].name, "語り継がれる", "レアリティ案1 第5段階")
	t.check_eq(db.item_display_name("iron_sword", ["life_1"]), "頑丈な鉄の剣", "付与効果名＋ベース名の連結だけ")
	db.free()


func test_text_plan_switch_and_ranks() -> void:
	var db := _db()
	# 案の切り替えはデータの番号だけ
	var e: TextEntry = db.text_of("skill", "slash")
	t.check_eq(e.display_name(2), "一文字斬り", "案2を引ける")
	t.check_eq(e.display_name(3), "旋り斬り", "案3を引ける")
	# レアリティ: rank 1〜6 が tier 順で揃い、3案とも6段階そろう
	for r: RarityDef in db.rarities:
		var te: TextEntry = db.text_of("rarity", r.id)
		t.check(te != null and te.rank == r.tier + 1, "rarity %s に rank がある" % r.id)
		t.check_eq(te.candidates.size(), 3, "rarity %s は3案" % r.id)
	db.rarity_plan = 3
	db._apply_texts()
	t.check_eq(db.rarities[0].name, "道端の品", "レアリティ案3に一括で切り替わる")
	t.check_eq(db.rarities[5].name, "物語が終わらない品", "第6段階も同じ案")
	db.free()


func test_text_has_no_numbers_and_all_have_three_plans() -> void:
	var db := _db()
	var single_plan_keys: Array[String] = [
		"skill:fire_ring", "skill:ice_shard", "skill:spark_shot",
		"skill:ground_slam", "skill:thrust", "skill:frost_lance",
		"support:heavy_blow", "support:wide_area", "support:chain_hop", "support:rapid_cast",
	]
	for key: String in db.texts:
		var te: TextEntry = db.texts[key]
		var expected_plans: int = 1 if single_plan_keys.has(key) else 3
		t.check_eq(te.candidates.size(), expected_plans, "%s の案数" % key)
	var errs: Array[String] = []
	TextEntry.from_dict({"category": "skill", "id": "x", "candidates": [{"plan": 1, "display_name": "a", "description": "ダメージ10増える"}]}, errs)
	t.check(errs.size() == 1, "説明文の数字を指摘する")
	db.free()


func test_t22_new_skills_supports_and_chains() -> void:
	var db := _db()
	t.check_eq(db.skills.size(), 14, "スキルは10個＋チェイン技4つで計14個")
	t.check_eq(db.droppable_skills().size(), 8, "ドロップするスキルは計8個（チェイン技は落ちない）")
	t.check_eq(db.supports.size(), 6, "補助ジェムは既存2＋追加4で計6個")
	t.check_eq(db.chains.size(), 6, "チェインは、砕氷・凍て槍・焔突き・雷落とし・溶岩玉・湯気爆ぜの6つ")
	# 砕氷（冷気の範囲→近接）だけが強すぎないよう、別の起点のチェインを足してある（弱めてはいない）
	var starts := {}
	for c: ChainRule in db.chains:
		starts[str(c.prev_tags)] = true
	t.check(starts.size() >= 4, "チェインの起点は、4種類以上ある（冷気の範囲だけに偏らない）")

	# 新しい5つの通常スキルが DataDB と droppable_skills() に入っていること
	var expected_skills: Dictionary = {
		"fire_ring": ["fire", "area", "ほむら輪"],
		"ice_shard": ["cold", "projectile", "氷つぶて"],
		"spark_shot": ["lightning", "projectile", "稲妻針"],
		"ground_slam": ["physical", "area", "地鳴らし"],
		"thrust": ["physical", "melee", "通し突き"],
	}
	var droppable_ids: Array[String] = []
	for s: SkillDef in db.droppable_skills():
		droppable_ids.append(s.id)
	for sid: String in expected_skills:
		var info: Array = expected_skills[sid]
		var s: SkillDef = db.skill(sid)
		t.check(s != null, "スキル %s が読み込まれている" % sid)
		if s != null:
			t.check_eq(s.element, info[0], "%s の element" % sid)
			t.check_eq(s.kind, info[1], "%s の kind" % sid)
			t.check(not s.chain_only, "%s は chain_only: false" % sid)
			t.check_eq(s.name, info[2], "%s の表示名" % sid)
			t.check(not s.description.is_empty(), "%s の説明文がある" % sid)
		t.check(droppable_ids.has(sid), "droppable_skills() に %s が入る" % sid)

	# 新しいチェイン専用技とチェインの動作
	var lance: SkillDef = db.skill("frost_lance")
	t.check(lance != null and lance.chain_only, "frost_lance はチェイン専用")
	t.check(not droppable_ids.has("frost_lance"), "frost_lance はドロップしない")
	t.check_eq(lance.name, "凍て槍", "frost_lance の表示名")
	var tr := ChainTracker.new()
	t.check_eq(tr.on_cast(db.skill("frost_bloom"), db.chains, db.skills).id, "frost_bloom", "起点の霜囲い")
	t.check_eq(tr.on_cast(db.skill("ice_shard"), db.chains, db.skills).id, "frost_lance", "霜囲い→氷つぶてで凍て槍に変化")

	# 新しい4つの補助ジェムと kinds の整合・表示名
	var heavy: SupportDef = db.support("heavy_blow")
	var wide: SupportDef = db.support("wide_area")
	var hop: SupportDef = db.support("chain_hop")
	var rapid: SupportDef = db.support("rapid_cast")
	t.check(heavy != null and wide != null and hop != null and rapid != null, "新しい補助ジェム4つが読み込まれている")
	t.check_eq(heavy.name, "重み乗せ", "heavy_blow の表示名")
	t.check_eq(wide.name, "大ぶり", "wide_area の表示名")
	t.check_eq(hop.name, "飛び移り", "chain_hop の表示名")
	t.check_eq(rapid.name, "早繰り", "rapid_cast の表示名")

	t.check(heavy.can_support(db.skill("slash")) and heavy.can_support(db.skill("fire_ring")) and heavy.can_support(db.skill("ice_shard")), "heavy_blow は全種類に付けられる")
	t.check(rapid.can_support(db.skill("thrust")) and rapid.can_support(db.skill("ground_slam")) and rapid.can_support(db.skill("spark_shot")), "rapid_cast は全種類に付けられる")
	t.check(wide.can_support(db.skill("fire_ring")) and wide.can_support(db.skill("thrust")), "wide_area は area と melee に付けられる")
	t.check(not wide.can_support(db.skill("ice_shard")), "wide_area は projectile には付けられない")
	t.check(hop.can_support(db.skill("ice_shard")) and hop.can_support(db.skill("spark_shot")), "chain_hop は projectile に付けられる")
	t.check(not hop.can_support(db.skill("slash")) and not hop.can_support(db.skill("ground_slam")), "chain_hop は melee や area には付けられない")

	# すべてのスキル・補助ジェムに names.json のエントリと名前・読み・説明文が入っていること
	for s: SkillDef in db.skills.values():
		var te: TextEntry = db.text_of("skill", s.id)
		t.check(te != null and not te.display_name().is_empty() and not te.reading().is_empty() and not te.description().is_empty(), "skill %s の名前・読み・説明文が揃っている" % s.id)
	for sup: SupportDef in db.supports.values():
		var te: TextEntry = db.text_of("support", sup.id)
		t.check(te != null and not te.display_name().is_empty() and not te.reading().is_empty() and not te.description().is_empty(), "support %s の名前・読み・説明文が揃っている" % sup.id)
	db.free()
