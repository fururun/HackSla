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
