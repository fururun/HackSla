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
	t.check_eq(db.enemy("swarmling").name, "群れ歯", "暫定採用: 小魔物")
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
	for key: String in db.texts:
		var te: TextEntry = db.texts[key]
		t.check_eq(te.candidates.size(), 3, "%s は3案" % key)
	var errs: Array[String] = []
	TextEntry.from_dict({"category": "skill", "id": "x", "candidates": [{"plan": 1, "display_name": "a", "description": "ダメージ10増える"}]}, errs)
	t.check(errs.size() == 1, "説明文の数字を指摘する")
	db.free()
