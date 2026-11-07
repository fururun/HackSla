extends RefCounted
## T09：ステータス・ダメージ計算・経験値とレベル

var t: Variant


func _skill(element: String) -> SkillDef:
	var errs: Array[String] = []
	return SkillDef.from_dict({"id": "x", "element": element, "kind": "melee", "damage": [10, 10]}, errs)


func test_stat_block_adds_and_merges() -> void:
	var a := StatBlock.from_dict({"damage_pct": 10, "life": 5})
	var b := StatBlock.from_dict({"damage_pct": 15, "armor": 20})
	a.merge(b)
	t.check_eq(a.get_value("damage_pct"), 25.0, "同じキーは足し算")
	t.check_eq(a.get_value("armor"), 20.0, "片方にしかないキーも入る")
	t.check_eq(a.get_value("fire_res"), 0.0, "無いキーは0")


func test_skill_damage_uses_generic_and_element_pct() -> void:
	var stats := StatBlock.from_dict({"damage_pct": 20, "fire_damage_pct": 30, "cold_damage_pct": 100})
	t.check(is_equal_approx(DamageCalc.skill_damage(_skill("fire"), stats, 10.0), 15.0), "火：10 ×（1 + 50%）= 15")
	t.check(is_equal_approx(DamageCalc.skill_damage(_skill("physical"), stats, 10.0), 12.0), "物理は属性の%を使わない")
	var minus := StatBlock.from_dict({"damage_pct": -300})
	t.check_eq(DamageCalc.skill_damage(_skill("fire"), minus, 10.0), 0.0, "マイナスにはならない")


func test_resistance_caps() -> void:
	t.check(is_equal_approx(DamageCalc.apply_resistance(100.0, "fire", 40.0), 60.0), "耐性40%で60")
	t.check(is_equal_approx(DamageCalc.apply_resistance(100.0, "fire", 90.0), 25.0), "耐性は75%で頭打ち")
	t.check(is_equal_approx(DamageCalc.apply_resistance(100.0, "fire", -150.0), 200.0), "耐性の下限は-100%（2倍まで）")
	t.check_eq(DamageCalc.apply_resistance(100.0, "physical", 75.0), 100.0, "物理には耐性を使わない")


func test_armor() -> void:
	t.check_eq(DamageCalc.apply_armor(100.0, 0.0), 100.0, "防御0ならそのまま")
	t.check(is_equal_approx(DamageCalc.apply_armor(100.0, 200.0), 50.0), "100×100÷(100+100)=50")
	var small := DamageCalc.apply_armor(10.0, 200.0) / 10.0
	var big := DamageCalc.apply_armor(1000.0, 200.0) / 1000.0
	t.check(big > small, "大きな一撃ほど防御で減りにくい")


func test_final_damage_routes_by_element() -> void:
	var atk := StatBlock.new()
	var target := StatBlock.from_dict({"armor": 20, "cold_res": 50})
	t.check(is_equal_approx(DamageCalc.final_damage(_skill("cold"), atk, target, 10.0), 5.0), "冷気は冷気耐性で減る")
	t.check(DamageCalc.final_damage(_skill("physical"), atk, target, 10.0) < 10.0, "物理は防御で減る")
	t.check_eq(DamageCalc.final_damage(_skill("fire"), atk, target, 10.0), 10.0, "火耐性0なら減らない")


func test_level_curve() -> void:
	t.check_eq(LevelCurve.xp_to_next(1), 20, "レベル1→2は20")
	t.check_eq(LevelCurve.xp_to_next(4), 160, "20×4^1.5=160")
	t.check_eq(LevelCurve.xp_to_next(LevelCurve.MAX_LEVEL), 0, "最大レベルでは0")


func test_add_xp_carries_over_and_gives_points() -> void:
	var s := LevelCurve.new_state()
	t.check_eq(LevelCurve.add_xp(s, 19), 0, "足りなければ上がらない")
	t.check_eq(LevelCurve.add_xp(s, 1 + 57 + 5), 2, "20で1→2、57で2→3、余り5")
	t.check_eq(s["level"], 3, "レベル3")
	t.check_eq(s["xp"], 5, "余りは繰り越す")
	t.check_eq(s["points"], 2, "1レベルにつきツリーのポイント1")


func test_max_level() -> void:
	var s := LevelCurve.new_state()
	LevelCurve.add_xp(s, LevelCurve.total_xp_to_max() + 99999)
	t.check_eq(s["level"], LevelCurve.MAX_LEVEL, "最大レベルで止まる")
	t.check_eq(s["xp"], 0, "最大レベルでは経験値を貯めない")
	t.check_eq(s["points"], LevelCurve.MAX_LEVEL - 1, "ポイントは最大で99")
	t.check_eq(LevelCurve.add_xp(s, 100), 0, "それ以上は上がらない")
