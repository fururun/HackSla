extends RefCounted
## プレイヤーの体力・死亡・経験値とレベル

var t: Variant


func test_damage_reduces_life() -> void:
	var v := PlayerVitals.new()
	var dealt: float = v.take_damage(10.0)
	t.check_eq(dealt, 10.0, "防御0なら素通し")
	t.check_eq(v.life, PlayerConsts.BASE_MAX_LIFE - 10.0, "体力が減る")


func test_life_regenerates_slowly_but_not_when_dead() -> void:
	var v := PlayerVitals.new()
	v.take_damage(30.0)
	var hurt: float = v.life
	v.tick(2.0)
	t.check(is_equal_approx(v.life, hurt + PlayerConsts.LIFE_REGEN_PER_SEC * 2.0), "時間でゆっくり回復する")
	v.tick(1000.0)
	t.check_eq(v.life, v.max_life(), "最大ライフを超えて回復しない")
	var d := PlayerVitals.new()
	d.take_damage(1000.0)
	t.check(d.is_dead(), "死んでいる")
	d.tick(10.0)
	t.check_eq(d.life, 0.0, "死んでいるときは回復しない")


func test_armor_reduces() -> void:
	var st := StatBlock.new()
	st.add("armor", 100)
	var v := PlayerVitals.new(st)
	var dealt: float = v.take_damage(10.0)
	t.check(dealt < 10.0 and dealt > 0.0, "防御で軽減される")


func test_invulnerability() -> void:
	var v := PlayerVitals.new()
	v.take_damage(10.0)
	t.check_eq(v.take_damage(10.0), 0.0, "無敵時間中は受けない")
	v.tick(PlayerConsts.HIT_INVULN + 0.01)
	t.check(v.take_damage(10.0) > 0.0, "無敵が切れたら受ける")


func test_death() -> void:
	var v := PlayerVitals.new()
	var died: Array = [0]
	v.died.connect(func() -> void: died[0] += 1)
	var dealt: float = v.take_damage(9999.0)
	t.check_eq(dealt, PlayerConsts.BASE_MAX_LIFE, "引かれるのは残り体力まで")
	t.check(v.is_dead(), "0で死ぬ")
	t.check_eq(died[0], 1, "died が出る")
	v.tick(1.0)
	t.check_eq(v.take_damage(10.0), 0.0, "死後は受けない")
	v.grant_xp(100000)
	t.check_eq(v.level, 1, "死後は経験値も入らない")
	t.check_eq(died[0], 1, "died は1回だけ")
	v.reset()
	t.check(not v.is_dead() and v.life == v.max_life(), "reset で復活")


func test_level_up_heals() -> void:
	var v := PlayerVitals.new()
	var ups: Array = []
	v.leveled_up.connect(func(l: int) -> void: ups.append(l))
	v.take_damage(50.0)
	v.grant_xp(LevelCurve.xp_to_next(1))
	t.check_eq(v.level, 2, "レベルが上がる")
	t.check_eq(ups, [2], "leveled_up が出る")
	t.check_eq(v.life, v.max_life(), "全回復")
	t.check_eq(v.points, LevelCurve.POINTS_PER_LEVEL, "ポイントが増える")


func test_xp_without_level_up() -> void:
	var v := PlayerVitals.new()
	v.take_damage(50.0)
	v.grant_xp(1)
	t.check_eq(v.level, 1, "足りなければ上がらない")
	t.check_eq(v.xp, 1, "経験値は貯まる")
	t.check_eq(v.life, PlayerConsts.BASE_MAX_LIFE - 50.0, "回復しない")


func test_max_level() -> void:
	var v := PlayerVitals.new()
	v.grant_xp(2000000000)
	t.check_eq(v.level, LevelCurve.MAX_LEVEL, "最大レベルで止まる")
	v.grant_xp(1000)
	t.check_eq(v.level, LevelCurve.MAX_LEVEL, "超えない")
	t.check_eq(v.xp, 0, "経験値は0のまま")


func test_max_life_from_stats() -> void:
	var st := StatBlock.new()
	var v := PlayerVitals.new(st)
	t.check_eq(v.max_life(), PlayerConsts.BASE_MAX_LIFE, "基本値")
	st.add("life", 30)
	t.check_eq(v.max_life(), PlayerConsts.BASE_MAX_LIFE + 30.0, "life で増える")
