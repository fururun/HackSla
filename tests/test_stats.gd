extends RefCounted
## ダメージ計算・ステータス・耐性・経験値とレベル

var t: Variant


func _skill(element: String) -> SkillDef:
	var s := SkillDef.new()
	s.element = element
	return s


func test_stat_block() -> void:
	var a := StatBlock.new()
	a.add("life", 10)
	a.add("life", 5)
	var b := StatBlock.new()
	b.add("life", 1)
	b.add("armor", 3)
	a.merge(b)
	t.check_eq(a.get_value("life"), 16.0, "足し合わせ")
	t.check_eq(a.get_value("armor"), 3.0, "merge で増える")
	t.check_eq(a.get_value("none"), 0.0, "無いキーは0")


func test_skill_damage() -> void:
	var st := StatBlock.new()
	st.add("damage_pct", 50)
	st.add("fire_damage_pct", 50)
	t.check_eq(DamageCalc.skill_damage(_skill("fire"), st, 10.0), 20.0, "全体+属性")
	t.check_eq(DamageCalc.skill_damage(_skill("cold"), st, 10.0), 15.0, "別属性は全体のみ")
	t.check_eq(DamageCalc.skill_damage(_skill("fire"), StatBlock.new(), 10.0), 10.0, "補正なし")


func test_resistance_bounds() -> void:
	t.check_eq(DamageCalc.apply_resistance(100.0, "fire", 50.0), 50.0, "50%")
	t.check_eq(DamageCalc.apply_resistance(100.0, "fire", 75.0), 25.0, "75%")
	t.check_eq(DamageCalc.apply_resistance(100.0, "fire", 200.0), 25.0, "上限75%")
	t.check_eq(DamageCalc.apply_resistance(100.0, "cold", -100.0), 200.0, "-100%")
	t.check_eq(DamageCalc.apply_resistance(100.0, "cold", -300.0), 200.0, "下限-100%")
	t.check_eq(DamageCalc.apply_resistance(100.0, "physical", 75.0), 100.0, "physical は耐性なし")


func test_armor() -> void:
	t.check_eq(DamageCalc.apply_armor(100.0, 0.0), 100.0, "armor 0")
	t.check_eq(DamageCalc.apply_armor(100.0, 100.0), 100.0 * 100.0 / 150.0, "armor 100")
	t.check_eq(DamageCalc.apply_armor(0.0, 100.0), 0.0, "ダメージ0")
	t.check(DamageCalc.apply_armor(50.0, 1000.0) < 50.0, "減る")


func test_xp_curve() -> void:
	t.check_eq(LevelCurve.xp_to_next(1), 20, "Lv1")
	t.check_eq(LevelCurve.xp_to_next(4), 160, "Lv4")
	t.check_eq(LevelCurve.xp_to_next(2), 57, "Lv2 四捨五入")


func test_add_xp_carry_over() -> void:
	var s := {"level": 1, "xp": 0, "points": 0}
	t.check_eq(LevelCurve.add_xp(s, 19), 0, "足りない")
	t.check_eq(s["level"], 1, "Lv1のまま")
	t.check_eq(LevelCurve.add_xp(s, 1), 1, "ちょうどで上がる")
	t.check_eq(s["xp"], 0, "繰り越し0")
	t.check_eq(s["points"], 1, "ポイント+1")
	# Lv2→3 は 57。20+57=77 を一度に入れて 2 つ上がり、余りが繰り越される
	var s2 := {"level": 1, "xp": 0, "points": 0}
	t.check_eq(LevelCurve.add_xp(s2, 80), 2, "2レベル上がる")
	t.check_eq(s2["level"], 3, "Lv3")
	t.check_eq(s2["xp"], 3, "余り3")
	t.check_eq(s2["points"], 2, "ポイント+2")


func test_max_level() -> void:
	var s := {"level": 99, "xp": 0, "points": 0}
	t.check_eq(LevelCurve.add_xp(s, 100000), 1, "Lv100で止まる")
	t.check_eq(s["level"], 100, "最大Lv100")
	t.check_eq(s["xp"], 0, "最大Lvでxpは0")
	t.check_eq(LevelCurve.add_xp(s, 500), 0, "最大Lvではもう上がらない")
	t.check_eq(s["points"], 1, "ポイントも増えない")
