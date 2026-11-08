class_name SkillCaster
extends Node
## スキルの実行本体：枠のスキルを取り出し、チェイン・補助ジェム・再使用時間を反映して当てる。
## 飛び道具・範囲の円はプールして使い回す。撃破時爆発は待ち行列で順に処理する（再帰しない）。

signal cast_done(slot: int, skill: SkillDef, hits: int, chained: bool)

## 1回の発動ぶんの情報（撃破時爆発の設定と、爆発の待ち行列）
class CastContext extends RefCounted:
	var skill: SkillDef
	var explode_chance: float = 0.0
	var explode_ratio: float = 0.0
	var queue: Array[Dictionary] = []  ## {pos: Vector2, damage: float}

var loadout := SkillLoadout.new()
var chain := ChainTracker.new()
var stats := StatBlock.new()
var rng := RandomNumberGenerator.new()
var fx_parent: Node  ## 弾・円・斬撃を置く先（プレイヤーの親）

var last_skill: SkillDef = null  ## 直近に実際に出した技（チェイン後の技を含む）
var last_chained: bool = false
var _fx_boost: float = 1.0  ## 技の絵の拡大（チェイン技は大きく出す）
var projectiles_created: int = 0  ## 弾を new した回数（プール再利用の確認用）
var fx_created: int = 0  ## エフェクトの部品を new した回数（プール再利用の確認用）

var _cooldowns: PackedFloat32Array = PackedFloat32Array()
var _free_projectiles: Array[SkillProjectile] = []
var _fx_pool: Array[SheetFx] = []
var _rings: Array[GroundRing] = []


func _init() -> void:
	_cooldowns.resize(SkillLoadout.SLOT_COUNT)
	rng.randomize()


func _physics_process(delta: float) -> void:
	tick(delta)


## 再使用時間を進める
func tick(delta: float) -> void:
	for i: int in _cooldowns.size():
		_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)


## この枠のスキルを使うときの、マナのコスト（補助ジェムの倍率つき。チェインで技が変わっても、元のスキルの分）
func mana_cost(slot: int) -> float:
	var skill := loadout.skill(slot)
	if skill == null:
		return 0.0
	var sup := loadout.support(slot)
	var mult: float = _mod(sup.modifiers, "mana_mult") if sup != null else 1.0
	return skill.mana_cost * mult


## スキルがあって、再使用時間が終わっている（マナは見ない）
func is_ready(slot: int) -> bool:
	return loadout.skill(slot) != null and cooldown_left(slot) <= 0.0


func cooldown_left(slot: int) -> float:
	return _cooldowns[slot - 1] if SkillLoadout.is_valid_slot(slot) else 0.0


## 枠のスキルを出す。出せなければ -1（空の枠・再使用時間中）。
## 出せたら、いま当てた敵の数（飛び道具は発射時点では 0）。
func cast(slot: int, target: Vector2, origin: Vector2, fallback_dir: Vector2 = Vector2.DOWN) -> int:
	var base := loadout.skill(slot)
	if base == null or _cooldowns[slot - 1] > 0.0:
		return -1

	var out := chain.on_cast(base, DataDB.chains, DataDB.skills)
	var chained := out != base
	_fx_boost = ChainFx.BOOST_SIZE if chained else 1.0
	var mods: Dictionary = {}
	var sup := loadout.support(slot)
	if sup != null:
		mods = sup.modifiers
	var dmg_mult := _mod(mods, "damage_mult")
	var area_mult := _mod(mods, "area_mult")
	if chained:
		dmg_mult *= _mod(mods, "chain_damage_mult")
		area_mult *= _mod(mods, "chain_area_mult")
	_cooldowns[slot - 1] = out.cooldown * _mod(mods, "cooldown_mult")

	var aim := target - origin
	if aim.length() < CombatConsts.MIN_AIM_DISTANCE:
		aim = fallback_dir
	aim = aim.normalized()

	var ctx := CastContext.new()
	ctx.skill = out
	ctx.explode_chance = float(mods.get("explode_on_kill", 0.0))
	ctx.explode_ratio = float(mods.get("explode_damage_ratio", 0.0))

	var hits := 0
	match out.kind:
		"melee":
			hits = _cast_melee(out, ctx, origin, aim, dmg_mult, area_mult)
		"area":
			hits = _cast_area(out, ctx, origin, dmg_mult, area_mult)
		"projectile":
			_cast_projectile(out, ctx, origin, aim, dmg_mult, area_mult, mods)
	_flush_explosions(ctx)
	_fx_boost = 1.0

	last_skill = out
	last_chained = chained
	cast_done.emit(slot, out, hits, chained)
	return hits


# ---- kind ごとの当て方 ----

func _cast_melee(skill: SkillDef, ctx: CastContext, origin: Vector2, aim: Vector2, dmg_mult: float, area_mult: float) -> int:
	var reach := (skill.range + skill.radius) * area_mult
	var hits := 0
	for n: Node in enemies():
		var e := n as Node2D
		if e != null and Iso.in_ground_arc(origin, aim, e.global_position, reach, CombatConsts.MELEE_HALF_ANGLE_DEG):
			_hit(e, _damage(skill, dmg_mult), skill, ctx)
			hits += 1
	# 画像は右向き。左向きのときは左右を反転し、傾きは反転後の角度にする（上下が逆さにならないように）
	var mirror := aim.x < 0.0
	var rot := SheetFx.rotation_for(aim)
	_play_fx(SheetFx.key_for_skill(skill), origin, reach, rot, mirror)
	return hits


func _cast_area(skill: SkillDef, ctx: CastContext, origin: Vector2, dmg_mult: float, area_mult: float) -> int:
	var radius := skill.radius * area_mult
	var hits := 0
	for n: Node in enemies():
		var e := n as Node2D
		if e != null and Iso.in_ground_circle(origin, e.global_position, radius):
			_hit(e, _damage(skill, dmg_mult), skill, ctx)
			hits += 1
	_play_ring(origin, radius, CombatConsts.ELEMENT_COLORS.get(skill.element, Color.WHITE))
	_play_fx(SheetFx.key_for_skill(skill), origin, radius)
	return hits


func _cast_projectile(skill: SkillDef, ctx: CastContext, origin: Vector2, aim: Vector2, dmg_mult: float,
		area_mult: float, mods: Dictionary) -> void:
	var count := 1 + maxi(0, int(mods.get("projectile_count", 0)))
	var hops := maxi(0, int(mods.get("hop_count", 0)))
	var base_ground := Vector2(aim.x, aim.y * 2.0).normalized()
	for i: int in count:
		var offset := deg_to_rad((float(i) - float(count - 1) * 0.5) * CombatConsts.PROJECTILE_SPREAD_DEG)
		var p := _take_projectile()
		p.launch(self, skill, ctx, origin, base_ground.rotated(offset), _damage(skill, dmg_mult), skill.radius * area_mult, hops)


## 弾が敵に当たったとき（SkillProjectile から呼ばれる）
func projectile_hit(proj: SkillProjectile, enemy: Node2D) -> void:
	_hit(enemy, proj.damage, proj.skill, proj.ctx)
	_flush_explosions(proj.ctx)


# ---- ダメージと撃破時爆発 ----

func _damage(skill: SkillDef, mult: float) -> float:
	return DamageCalc.skill_damage(skill, stats, skill.roll_damage(rng)) * mult


## 1体に当てる。倒れたら（active が false になったら）確率で爆発を待ち行列に積む
func _hit(enemy: Node2D, amount: float, skill: SkillDef, ctx: CastContext) -> void:
	var alive_before := _alive(enemy)
	enemy.call("take_hit", amount, skill)
	_play_fx(SheetFx.hit_key(skill.element), enemy.global_position + CombatConsts.HIT_FX_OFFSET)  # 当たった場所の火花
	if alive_before and not _alive(enemy) and ctx.explode_chance > 0.0 and rng.randf() < ctx.explode_chance:
		ctx.queue.append({"pos": enemy.global_position, "damage": _max_life(enemy) * ctx.explode_ratio})


## 爆発を待ち行列の順に処理する。倒れた敵がさらに積むので、連鎖は打ち止めなし。
## 敵は1体につき1回しか倒れない（倒れた敵は enemies グループから外れる）ので、必ず終わる。
func _flush_explosions(ctx: CastContext) -> void:
	var i := 0
	while i < ctx.queue.size():
		var ex: Dictionary = ctx.queue[i]
		i += 1
		var pos: Vector2 = ex["pos"]
		_play_ring(pos, CombatConsts.EXPLOSION_RADIUS, Color("#ffb03d"))
		_play_fx(SheetFx.explosion_key(), pos, CombatConsts.EXPLOSION_RADIUS)
		for n: Node in enemies():
			var e := n as Node2D
			if e != null and Iso.in_ground_circle(pos, e.global_position, CombatConsts.EXPLOSION_RADIUS):
				_hit(e, float(ex["damage"]), ctx.skill, ctx)
	ctx.queue.clear()


static func _alive(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	var a: Variant = enemy.get("active")  # 倒れない的（案山子）は active を持たない
	return a == null or bool(a)


static func _max_life(enemy: Node) -> float:
	var d: Variant = enemy.get("definition")
	return (d as EnemyDef).life if d is EnemyDef else 0.0


static func enemy_radius(enemy: Node) -> float:
	var r: Variant = enemy.get("hit_radius")
	return float(r) if r != null else CombatConsts.DEFAULT_ENEMY_RADIUS


static func _mod(mods: Dictionary, key: String) -> float:
	return float(mods.get(key, 1.0))


func enemies() -> Array[Node]:
	if fx_parent == null or not fx_parent.is_inside_tree():
		return []
	return fx_parent.get_tree().get_nodes_in_group("enemies")


# ---- プール ----

func _take_projectile() -> SkillProjectile:
	if not _free_projectiles.is_empty():
		return _free_projectiles.pop_back()
	var p := SkillProjectile.new()
	projectiles_created += 1
	fx_parent.add_child(p)
	return p


func recycle_projectile(p: SkillProjectile) -> void:
	_free_projectiles.append(p)


## 範囲の輪（地面の円）を1つ出す。使い回しで、同時数の上限を超えたら一番古いものを再利用する
func _play_ring(pos: Vector2, radius: float, color: Color) -> void:
	if fx_parent == null:
		return
	var ring: GroundRing = null
	for r: GroundRing in _rings:
		if not r.busy:
			ring = r
			break
	if ring == null:
		if _rings.size() < CombatConsts.MAX_RINGS:
			ring = GroundRing.new()
			fx_parent.add_child(ring)
			_rings.append(ring)
		else:
			ring = _rings.pop_front()
			_rings.append(ring)
	ring.play(pos, radius, color)


## チェイン技の演出（pixelfx の絵を重ねる）。技ごとに決めた絵（data/fx/sheets.json の chain_fx）を、
## 足元（origin）と、当たる場所（target）に出す。target の絵は、少しずつ遅らせて、重ねていく
func play_chain_fx(skill: SkillDef, origin: Vector2, target: Vector2) -> void:
	if fx_parent == null or not fx_parent.is_inside_tree():
		return
	var saved: float = _fx_boost
	_fx_boost = 1.0
	var keys: Dictionary = SheetFx.chain_keys(skill)
	for key: Variant in keys["origin"]:
		_play_fx(str(key), origin)
	var index: int = 0
	for key: Variant in keys["target"]:
		var delay: float = 0.07 * float(index)
		index += 1
		var position: Vector2 = target
		if delay <= 0.0:
			_play_fx(str(key), position)
			continue
		var timer: SceneTreeTimer = fx_parent.get_tree().create_timer(delay, true, true)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(fx_parent):
				_play_fx(str(key), position))
	_fx_boost = saved


## スプライトシートのエフェクトを1つ再生する。使い回し（プール）で、同時数の上限を超えたら一番古いものを再利用する。
## size_px が正なら、絵の「届く距離」がそのドット数になるよう拡大縮小する（範囲・斬撃の実際の範囲に合わせる）
func _play_fx(key: String, pos: Vector2, size_px: float = 0.0, rot: float = 0.0, mirror: bool = false) -> void:
	if fx_parent == null or key.is_empty():
		return
	var fx: SheetFx = null
	for f: SheetFx in _fx_pool:
		if not f.busy:
			fx = f
			break
	if fx == null:
		if _fx_pool.size() < CombatConsts.MAX_SHEET_FX:
			fx = SheetFx.new()
			fx_created += 1
			fx_parent.add_child(fx)
			_fx_pool.append(fx)
		else:
			fx = _fx_pool.pop_front()  # 一番古いものを再利用（末尾へ回す）
			_fx_pool.append(fx)
	fx.play(key, pos, size_px * _fx_boost, rot, mirror)
