extends RefCounted
## T10：スキル枠・チェイン・補助ジェム・撃破時爆発・再使用時間・弾のプール

var t: Variant

const ORIGIN: Vector2 = Vector2(-20, 0)


# ---- 下準備 ----

func _db() -> Node:
	return (t as SceneTree).root.get_node("DataDB")


func _world() -> Node2D:
	var world := Node2D.new()
	(t as SceneTree).root.add_child(world)
	return world


func _manager(world: Node2D) -> EnemyManager:
	var m := EnemyManager.new()
	world.add_child(m)
	m.set_physics_process(false)
	return m


func _caster(world: Node2D) -> SkillCaster:
	var c := SkillCaster.new()
	c.fx_parent = world
	c.rng.seed = 1234
	return c


## テスト用の補助ジェムを DataDB に一時登録する
func _add_support(id: String, kinds: Array, modifiers: Dictionary) -> void:
	var errors: Array[String] = []
	var s := SupportDef.from_dict({"id": id, "kinds": kinds, "modifiers": modifiers}, errors)
	t.check(errors.is_empty(), "テスト用補助ジェムが作れる: %s" % str(errors))
	_db().supports[id] = s


func _remove_supports(ids: Array) -> void:
	for id: String in ids:
		_db().supports.erase(id)


func _active_projectiles(world: Node) -> Array[SkillProjectile]:
	var out: Array[SkillProjectile] = []
	for c: Node in world.get_children():
		if c is SkillProjectile and (c as SkillProjectile).active:
			out.append(c)
	return out


func _finish_projectiles(world: Node) -> void:
	for p: SkillProjectile in _active_projectiles(world):
		p.advance(2.0)


func _cleanup(world: Node2D, caster: SkillCaster) -> void:
	caster.free()
	world.queue_free()
	await (t as SceneTree).process_frame


# ---- スキル枠 ----

func test_loadout_defaults_and_swap() -> void:
	var l := SkillLoadout.new()
	t.check_eq(l.skill_id(1), "slash", "枠1は斬撃")
	t.check_eq(l.skill_id(2), "frost_bloom", "枠2は氷華")
	t.check_eq(l.skill_id(3), "fire_bolt", "枠3は火球")
	t.check_eq(l.skill_id(4), "", "枠4は空")
	t.check_eq(l.support_id(1), "", "補助ジェムは最初は無し")
	t.check(not l.set_support(1, "scatter"), "拡散は飛び道具にしか付けられない")
	t.check(l.set_support(3, "scatter"), "火球に拡散を付けられる")
	t.check(l.set_support(1, "burst_on_kill"), "撃破時爆発はどのスキルにも付けられる")
	t.check(not l.set_support(4, "burst_on_kill"), "空の枠には付けられない")
	t.check(not l.set_support(3, "no_such_support"), "存在しない補助ジェムは付けられない")
	t.check(not l.set_skill(9, "slash"), "範囲外の枠は変えられない")
	t.check(not l.set_skill(4, "no_such_skill"), "存在しないスキルは入れられない")
	var changed: Array[int] = []
	l.changed.connect(func(slot: int) -> void: changed.append(slot))
	t.check(l.set_skill(3, "slash"), "スキルを付け替えられる")
	t.check_eq(l.support_id(3), "", "付けられない種類になった補助ジェムは外れる")
	t.check(l.set_skill(4, "shatter"), "空の枠にも入れられる")
	t.check_eq(changed, [3, 4], "付け替えで changed が出る")
	t.check(l.clear_skill(1), "空にできる")
	t.check_eq(l.support_id(1), "", "空にすると補助ジェムも外れる")


# ---- チェイン ----

func test_chain_triggers_and_breaks() -> void:
	var world := _world()
	var c := _caster(world)
	t.check(c.cast(2, ORIGIN, ORIGIN) >= 0, "氷華が出る")
	t.check_eq(c.last_skill.id, "frost_bloom", "氷華が出た")
	t.check(c.cast(1, ORIGIN + Vector2(10, 0), ORIGIN) >= 0, "氷華のあとに近接が出る")
	t.check_eq(c.last_skill.id, "shatter", "氷華→斬撃で砕氷に変わる")
	t.check(c.last_chained, "チェインしたと記録される")
	c.tick(5.0)
	c.cast(1, ORIGIN + Vector2(10, 0), ORIGIN)
	t.check_eq(c.last_skill.id, "slash", "チェイン技のあとは数え直し（砕氷は起点にならない）")
	t.check(not c.last_chained, "チェインしていない")

	# 間に別のスキルを挟むと無効
	c.tick(5.0)
	c.cast(2, ORIGIN, ORIGIN)
	c.cast(3, ORIGIN + Vector2(10, 0), ORIGIN)
	c.tick(5.0)
	c.cast(1, ORIGIN + Vector2(10, 0), ORIGIN)
	t.check_eq(c.last_skill.id, "slash", "間に火球を挟むとチェインしない")

	# 受付時間は無制限
	c.tick(5.0)
	c.cast(2, ORIGIN, ORIGIN)
	c.tick(600.0)
	c.cast(1, ORIGIN + Vector2(10, 0), ORIGIN)
	t.check_eq(c.last_skill.id, "shatter", "時間が空いてもチェインする")
	await _cleanup(world, c)


func test_chain_multipliers_apply_only_on_chain() -> void:
	var world := _world()
	var mgr := _manager(world)
	var brute: Enemy = mgr.spawn(_db().enemy("brute"), Vector2(0, 0))
	var c := _caster(world)
	_add_support("t_chain", [], {"chain_damage_mult": 2.0, "chain_area_mult": 2.0})
	c.loadout.set_support(1, "t_chain")

	c.cast(1, Vector2(40, 0), ORIGIN)  # チェインなしの斬撃
	var normal: float = brute.definition.life - brute.life
	t.check(normal >= 14.0 and normal <= 22.0, "チェインしないときは chain_damage_mult が効かない（%f）" % normal)

	brute.life = brute.definition.life
	c.tick(5.0)
	c.cast(2, ORIGIN, ORIGIN)
	c.cast(1, Vector2(40, 0), ORIGIN)
	var chained: float = brute.definition.life - brute.life
	t.check(chained >= 144.0 and chained <= 192.0, "砕氷に chain_damage_mult が効く（%f）" % chained)

	# chain_area_mult：砕氷の届く距離 (28+42) が 2 倍になる
	brute.life = brute.definition.life
	brute.global_position = Vector2(-20 + 120, 0)  # 通常 70 では届かず、2倍 140 なら届く
	c.tick(5.0)
	c.chain.reset()
	c.cast(2, ORIGIN, ORIGIN)
	c.cast(1, Vector2(100, 0), ORIGIN)
	t.check(brute.life < brute.definition.life, "chain_area_mult で砕氷の範囲が広がる")
	_remove_supports(["t_chain"])
	await _cleanup(world, c)


# ---- 補助ジェム ----

func test_support_projectile_count() -> void:
	var world := _world()
	var c := _caster(world)
	c.cast(3, Vector2(100, 0), ORIGIN)
	t.check_eq(_active_projectiles(world).size(), 1, "補助なしなら弾は1発")
	_finish_projectiles(world)
	c.tick(5.0)
	c.loadout.set_support(3, "scatter")
	c.cast(3, Vector2(100, 0), ORIGIN)
	var ps := _active_projectiles(world)
	t.check_eq(ps.size(), 3, "拡散で弾が3発")
	# 扇状に等間隔：真ん中は狙い方向、両端は左右対称
	var ys: Array[float] = []
	for p: SkillProjectile in ps:
		p.advance(0.1)
		ys.append(p.global_position.y)
	ys.sort()
	t.check(absf(ys[1]) < 0.01, "真ん中の弾は狙った方向")
	t.check(absf(ys[0] + ys[2]) < 0.01 and ys[2] > 0.5, "両端は左右対称に開く")
	_finish_projectiles(world)
	await _cleanup(world, c)


func test_support_damage_mult() -> void:
	var world := _world()
	var mgr := _manager(world)
	var brute: Enemy = mgr.spawn(_db().enemy("brute"), Vector2(10, 0))
	var c := _caster(world)
	_add_support("t_dmg", ["projectile"], {"damage_mult": 3.0})
	c.cast(3, Vector2(100, 0), ORIGIN)
	_finish_projectiles(world)
	var base: float = brute.definition.life - brute.life
	t.check(base >= 18.0 and base <= 26.0, "補助なしの火球は 18〜26（%f）" % base)

	brute.life = brute.definition.life
	c.tick(5.0)
	c.loadout.set_support(3, "t_dmg")
	c.cast(3, Vector2(100, 0), ORIGIN)
	_finish_projectiles(world)
	var boosted: float = brute.definition.life - brute.life
	t.check(boosted >= 54.0 and boosted <= 78.0, "damage_mult 3 で 54〜78（%f）" % boosted)

	# 実データの拡散は 1 発あたり 0.85 倍
	brute.life = brute.definition.life
	c.tick(5.0)
	c.loadout.set_support(3, "scatter")
	c.cast(3, Vector2(100, 0), ORIGIN)
	_finish_projectiles(world)
	var per_hit: float = brute.definition.life - brute.life
	t.check(per_hit > 0.0, "拡散でも当たる")
	_remove_supports(["t_dmg"])
	await _cleanup(world, c)


func test_support_area_mult_on_area_skill() -> void:
	var world := _world()
	var mgr := _manager(world)
	var near_far: Enemy = mgr.spawn(_db().enemy("brute"), Vector2(-20 + 70, 0))  # 氷華の半径 48 の外
	var c := _caster(world)
	_add_support("t_area", [], {"area_mult": 2.0})
	t.check_eq(c.cast(2, ORIGIN, ORIGIN), 0, "半径 48 の外には当たらない")
	c.tick(5.0)
	c.loadout.set_support(2, "t_area")
	t.check_eq(c.cast(2, ORIGIN, ORIGIN), 1, "area_mult 2 なら届く")
	t.check(near_far.life < near_far.definition.life, "ダメージが入る")
	_remove_supports(["t_area"])
	await _cleanup(world, c)


func test_projectile_hop() -> void:
	var world := _world()
	var mgr := _manager(world)
	var a: Enemy = mgr.spawn(_db().enemy("brute"), Vector2(10, 0))
	var b: Enemy = mgr.spawn(_db().enemy("brute"), Vector2(10, 30))  # 脇にいる別の敵
	var c := _caster(world)
	c.cast(3, Vector2(100, 0), ORIGIN)
	_finish_projectiles(world)
	t.check(a.life < a.definition.life and b.life == b.definition.life, "hop なしは1体だけ")

	a.life = a.definition.life
	_add_support("t_hop", ["projectile"], {"hop_count": 1})
	c.tick(5.0)
	c.loadout.set_support(3, "t_hop")
	c.cast(3, Vector2(100, 0), ORIGIN)
	_finish_projectiles(world)
	t.check(a.life < a.definition.life and b.life < b.definition.life, "hop 1 で近くの敵にも伝わる")
	t.check_eq(_active_projectiles(world).size(), 0, "伝わり終わったら弾は消える")
	_remove_supports(["t_hop"])
	await _cleanup(world, c)


# ---- 再使用時間 ----

func test_cooldown() -> void:
	var world := _world()
	var c := _caster(world)
	t.check(c.cast(1, Vector2(40, 0), ORIGIN) >= 0, "最初は出せる")
	t.check_eq(c.cast(1, Vector2(40, 0), ORIGIN), -1, "再使用時間中は出せない")
	t.check_eq(c.chain.last_skill.id, "slash", "出せなかった発動はチェインの記録を変えない")
	t.check(c.cast(2, ORIGIN, ORIGIN) >= 0, "別の枠は別々に数える")
	t.check(absf(c.cooldown_left(1) - 0.5) < 0.001, "斬撃の再使用時間は 0.5 秒")
	c.tick(0.3)
	t.check_eq(c.cast(1, Vector2(40, 0), ORIGIN), -1, "0.3 秒ではまだ")
	c.tick(0.25)
	t.check(c.cast(1, Vector2(40, 0), ORIGIN) >= 0, "経てば出せる")
	t.check_eq(c.cast(4, Vector2(40, 0), ORIGIN), -1, "空の枠は出せない")

	_add_support("t_fast", [], {"cooldown_mult": 0.5})
	c.loadout.set_support(1, "t_fast")
	c.tick(10.0)
	c.cast(1, Vector2(40, 0), ORIGIN)
	t.check(absf(c.cooldown_left(1) - 0.25) < 0.001, "cooldown_mult 0.5 で半分")
	_remove_supports(["t_fast"])
	await _cleanup(world, c)


# ---- 弾のプール ----

func test_projectile_pool_reuse() -> void:
	var world := _world()
	var c := _caster(world)
	c.cast(3, Vector2(100, 0), ORIGIN)
	var first: SkillProjectile = _active_projectiles(world)[0]
	t.check_eq(c.projectiles_created, 1, "弾を1つ作った")
	_finish_projectiles(world)
	t.check(not first.active and not first.visible, "射程の終わりで弾が戻る")
	c.tick(5.0)
	c.cast(3, Vector2(100, 0), ORIGIN)
	t.check_eq(c.projectiles_created, 1, "2回目は作り直さない")
	t.check(_active_projectiles(world)[0] == first, "同じ弾を使い回す")
	_finish_projectiles(world)

	# 拡散 3 発を何度撃っても、作る数は 3 のまま
	c.loadout.set_support(3, "scatter")
	for i: int in 5:
		c.tick(5.0)
		c.cast(3, Vector2(100, 0), ORIGIN)
		_finish_projectiles(world)
	t.check_eq(c.projectiles_created, 3, "弾の総数は増えない")
	var count := 0
	for ch: Node in world.get_children():
		if ch is SkillProjectile:
			count += 1
	t.check_eq(count, 3, "ノードも増えない")
	await _cleanup(world, c)


# ---- 撃破時爆発 ----

func _line_of_enemies(mgr: EnemyManager, n: int, spacing: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for i: int in n:
		out.append(mgr.spawn(_db().enemy("swarmling"), Vector2(i * spacing, 0)))
	return out


func test_explosion_chain_clears_everything() -> void:
	var world := _world()
	var mgr := _manager(world)
	var line := _line_of_enemies(mgr, 40, 16.0)
	line[0].life = 1.0  # 斬撃で確実に倒れるのは先頭だけ
	_add_support("t_boom", [], {"explode_on_kill": 1.0, "explode_damage_ratio": 1.5})
	var c := _caster(world)
	c.loadout.set_support(1, "t_boom")
	c.cast(1, Vector2(40, 0), ORIGIN)
	t.check_eq(mgr.active_count(), 0, "連鎖して40体が全滅する（打ち止めなし）")
	t.check_eq(mgr.pooled_count(), 40, "全員プールに戻る")
	_remove_supports(["t_boom"])
	await _cleanup(world, c)


func test_explosion_needs_support_and_probability() -> void:
	var world := _world()
	var mgr := _manager(world)
	var line := _line_of_enemies(mgr, 10, 16.0)
	line[0].life = 1.0
	var c := _caster(world)
	c.cast(1, Vector2(40, 0), ORIGIN)
	t.check(mgr.active_count() >= 7, "補助なしなら連鎖しない（残り %d）" % mgr.active_count())
	await _cleanup(world, c)

	# 確率 0 なら爆発しない
	world = _world()
	mgr = _manager(world)
	line = _line_of_enemies(mgr, 10, 16.0)
	line[0].life = 1.0
	_add_support("t_never", [], {"explode_on_kill": 0.0, "explode_damage_ratio": 1.5})
	c = _caster(world)
	c.loadout.set_support(1, "t_never")
	c.cast(1, Vector2(40, 0), ORIGIN)
	t.check(mgr.active_count() >= 7, "確率 0 なら爆発しない")
	_remove_supports(["t_never"])
	await _cleanup(world, c)


func test_explosion_damage_uses_killed_enemy_max_life() -> void:
	var world := _world()
	var mgr := _manager(world)
	var victim: Enemy = mgr.spawn(_db().enemy("swarmling"), Vector2(0, 0))  # 最大ライフ 20
	var brute: Enemy = mgr.spawn(_db().enemy("brute"), Vector2(14, 0))  # 爆発の範囲内
	victim.life = 1.0
	_add_support("t_boom2", [], {"explode_on_kill": 1.0, "explode_damage_ratio": 1.5})
	var c := _caster(world)
	c.loadout.set_support(3, "t_boom2")
	c.cast(3, Vector2(100, 0), Vector2(-30, 0))
	_finish_projectiles(world)
	t.check(not victim.active, "火球で倒れる")
	var dealt: float = brute.definition.life - brute.life
	var victim_life: float = victim.definition.life  # スライムの最大ライフ（調整で変わる）
	t.check(absf(dealt - victim_life * 1.5) < 0.001, "爆発のダメージは 倒した敵の最大ライフ%d × 1.5（実際 %f）" % [int(victim_life), dealt])
	_remove_supports(["t_boom2"])
	await _cleanup(world, c)


func test_real_burst_support_data_works() -> void:
	# 実データの撃破時爆発（確率 0.6）でも、必ず終わる
	var world := _world()
	var mgr := _manager(world)
	var line := _line_of_enemies(mgr, 30, 10.0)
	for e: Enemy in line:
		e.life = 1.0
	var c := _caster(world)
	t.check(c.loadout.set_support(1, "burst_on_kill"), "実データの補助ジェムを付けられる")
	c.cast(1, Vector2(40, 0), ORIGIN)
	t.check(mgr.active_count() < 30, "少なくとも何体かは倒れる")
	await _cleanup(world, c)
