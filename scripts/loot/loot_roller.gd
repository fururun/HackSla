class_name LootRoller
extends RefCounted
## 戻り値は ItemInstance / GemInstance / int（通貨数）の混在配列。
## 仮ルールだけをここに集約。装備性能・レアリティ・付与効果は DataDB を使う。

const XP_PER_DROP: int = 10
const MIN_DROPS: int = 1
const ITEM_WEIGHT: float = 3.0
const GEM_WEIGHT: float = 1.0
const GEM_NEW_WEIGHT_MULT: float = 4.0
const CURRENCY_WEIGHT: float = 6.0
const CURRENCY_PER_XP: int = 1

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng


func roll_rarity(min_tier: int = 0) -> RarityDef:
	if min_tier <= 0:
		return _weighted_pick(DataDB.rarities) as RarityDef
	var allowed: Array = DataDB.rarities.filter(func(r: RarityDef) -> bool: return r.tier >= min_tier)
	if allowed.is_empty():
		return _weighted_pick(DataDB.rarities) as RarityDef
	return _weighted_pick(allowed) as RarityDef


## レベルに合う土台、または抽選可能なレアリティがなければ null。
func roll_item(level: int, min_tier: int = 0) -> ItemInstance:
	var bases: Array[ItemBaseDef] = []
	for base: ItemBaseDef in DataDB.bases.values():
		if base.level <= level:
			bases.append(base)
	if bases.is_empty():
		return null
	var rarity: RarityDef = roll_rarity(min_tier)
	if rarity == null:
		return null
	var item: ItemInstance = ItemInstance.new()
	item.base = bases[_rng.randi_range(0, bases.size() - 1)]
	item.rarity = rarity
	var candidates: Array[AffixDef] = []
	for affix: AffixDef in DataDB.affixes.values():
		if affix.weight > 0.0 and affix.can_roll_on(item.base.slot):
			candidates.append(affix)
	# 現データには指定数より候補が少ない部位がある。重複で埋めず候補数を上限にする。
	var count: int = mini(_rng.randi_range(rarity.affix_min, rarity.affix_max), candidates.size())
	for index: int in range(count):
		var affix: AffixDef = _weighted_pick(candidates) as AffixDef
		item.affixes.append({"id": affix.id, "value": roundi(_rng.randf_range(affix.value_min, affix.value_max))})
		candidates.erase(affix)
	return item


## xp が正なら最低1枠、XP_PER_DROP ごとに1枠増加。xp 0 の敵は何も落とさない。
## 通貨は末尾の int 1件へ集約する。候補のない装備/ジェム枠は通貨にする。
func roll_drops(enemy: EnemyDef, level: int, owned_gems: Dictionary = {}) -> Array:
	var drops: Array = []
	if enemy.xp <= 0:
		return drops
	var count: int = MIN_DROPS + floori(float(enemy.xp) / XP_PER_DROP)
	var currency: int = 0
	for index: int in range(count):
		var choice: float = _rng.randf() * (ITEM_WEIGHT + GEM_WEIGHT + CURRENCY_WEIGHT)
		if choice < ITEM_WEIGHT:
			var item: ItemInstance = roll_item(level)
			if item != null:
				drops.append(item)
				continue
		elif choice < ITEM_WEIGHT + GEM_WEIGHT:
			var gem: GemInstance = _roll_gem(owned_gems)
			if gem != null:
				drops.append(gem)
				continue
		currency += enemy.xp * CURRENCY_PER_XP
	for i: int in enemy.guaranteed_items:  # レアモンスターは、レア以上の装備を必ず落とす
		var bonus: ItemInstance = roll_item(level, enemy.guaranteed_min_tier)
		if bonus != null:
			drops.append(bonus)
	if currency > 0:
		drops.append(currency)
	return drops


const RARE_SKILL_CHANCE: float = 0.04  ## ジェムが落ちるとき、レアスキルになる確率（超低確率）


func _roll_gem(owned_gems: Dictionary = {}) -> GemInstance:
	var gems: Array[GemInstance] = []
	for skill: SkillDef in DataDB.droppable_skills():
		gems.append(GemInstance.new(GemInstance.Kind.SKILL, skill.id))
	for support: SupportDef in DataDB.supports.values():
		gems.append(GemInstance.new(GemInstance.Kind.SUPPORT, support.id))
	# レアスキル：ふつうの宝石の RARE_SKILL_WEIGHT 倍しか出ない（重みをつけて混ぜる）
	var rare: Array[SkillDef] = DataDB.rare_skills()
	if not rare.is_empty() and _rng.randf() < RARE_SKILL_CHANCE:
		return GemInstance.new(GemInstance.Kind.SKILL, rare[_rng.randi_range(0, rare.size() - 1)].id)
	if gems.is_empty():
		return null
	# 引数省略時は乱数の消費も従来どおり。
	if owned_gems.is_empty():
		return gems[_rng.randi_range(0, gems.size() - 1)]
	var total: float = 0.0
	for gem: GemInstance in gems:
		total += 1.0 if owned_gems.get(gem.kind, {}).has(gem.id) else GEM_NEW_WEIGHT_MULT
	var choice: float = _rng.randf() * total
	for gem: GemInstance in gems:
		var weight: float = 1.0 if owned_gems.get(gem.kind, {}).has(gem.id) else GEM_NEW_WEIGHT_MULT
		if choice < weight:
			return gem
		choice -= weight
	return gems.back()


## weight <= 0 は候補外。全候補が無効なら null。
func _weighted_pick(candidates: Array) -> RefCounted:
	var total: float = 0.0
	var last: RefCounted = null
	for candidate: RefCounted in candidates:
		if candidate.weight > 0.0:
			total += candidate.weight
			last = candidate
	if last == null:
		return null
	var choice: float = _rng.randf() * total
	for candidate: RefCounted in candidates:
		if candidate.weight <= 0.0:
			continue
		if choice < candidate.weight:
			return candidate
		choice -= candidate.weight
	return last
