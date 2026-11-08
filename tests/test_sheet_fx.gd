extends RefCounted
## スプライトシート（pixelfx）のエフェクト：設定の対応づけ、再生の進み方、プールの上限

var t: Variant


func _skill(id: String) -> SkillDef:
	return DataDB.skill(id)


func test_keys_follow_kind_and_element() -> void:
	t.check_eq(SheetFx.key_for_skill(_skill("slash")), "slash", "近接の斬撃")
	t.check_eq(SheetFx.key_for_skill(_skill("shatter")), "slash_cold", "個別の指定が先")
	t.check_eq(SheetFx.key_for_skill(_skill("thrust")), "thrust", "突き")
	t.check_eq(SheetFx.key_for_skill(_skill("frost_bloom")), "area_cold", "冷気の範囲")
	t.check_eq(SheetFx.key_for_skill(_skill("fire_ring")), "area_fire", "火の範囲")
	t.check_eq(SheetFx.key_for_skill(_skill("fire_bolt")), "proj_fire", "火の飛び道具")
	t.check_eq(SheetFx.hit_key("cold"), "hit_cold", "冷気の命中")
	t.check(not SheetFx.explosion_key().is_empty(), "爆発のキーがある")


func test_every_configured_sheet_loads() -> void:
	for key: String in SheetFx.config().get("sheets", {}):
		var def := SheetFx.def_of(key)
		t.check(not def.is_empty() and def["texture"] != null, "シートを読める: %s" % key)


func test_every_skill_has_art() -> void:
	for id: String in DataDB.skills:
		var key := SheetFx.key_for_skill(DataDB.skills[id])
		t.check(not SheetFx.def_of(key).is_empty(), "全スキルに絵がある: %s" % id)


func test_one_shot_plays_then_finishes() -> void:
	var fx := SheetFx.new()
	var done := [false]
	fx.finished.connect(func(_f: SheetFx) -> void: done[0] = true)
	t.check(fx.play("slash", Vector2.ZERO, 40.0), "再生を始められる")
	t.check(fx.busy, "再生中")
	fx.advance(0.05)
	t.check(fx.busy, "少し進んでもまだ再生中")
	fx.advance(3.0)
	t.check(not fx.busy and done[0], "終わったら止まって finished が出る")
	fx.free()


func test_loop_keeps_playing_and_size_fits_reach() -> void:
	var fx := SheetFx.new()
	fx.play("proj_fire", Vector2.ZERO)
	for i in 100:
		fx.advance(0.1)
	t.check(fx.busy, "ループは止まらない")
	fx.stop()
	fx.play("area_cold", Vector2.ZERO, 48.0)
	var cold := SheetFx.def_of("area_cold")
	t.check_eq(snappedf(fx.scale.x, 0.001), snappedf(48.0 * float(cold["fit"]) / float(cold["ref"]), 0.001), "範囲の半径（×収める割合）に合わせて拡大縮小される")
	# 左向きの回転は反転後の向きに合わせて符号が逆になる（斜め下向きが斜め上向きにならない）
	t.check(SheetFx.rotation_for(Vector2(-1, 0.5)) < 0.0 and SheetFx.rotation_for(Vector2(1, 0.5)) > 0.0, "左向きの傾きは右向きと符号が逆")
	t.check_eq(snappedf(SheetFx.rotation_for(Vector2(1, 0)), 0.001), 0.0, "真右は傾きなし")
	fx.play("slash", Vector2.ZERO, 40.0, 0.0, true)
	t.check(fx.scale.x < 0.0, "左向きは左右反転")
	fx.free()


func test_caster_pool_is_bounded_and_reused() -> void:
	var holder := Node2D.new()
	(t as SceneTree).root.add_child(holder)
	var caster := SkillCaster.new()
	caster.fx_parent = holder
	for i in CombatConsts.MAX_SHEET_FX + 40:
		caster._play_fx("hit_fire", Vector2(i, 0))
	t.check_eq(caster._fx_pool.size(), CombatConsts.MAX_SHEET_FX, "同時数の上限を超えて作らない")
	t.check_eq(caster.fx_created, CombatConsts.MAX_SHEET_FX, "作った数も上限まで")
	caster.free()
	holder.queue_free()
