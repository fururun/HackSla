extends Node
## data/ のJSONをすべて読み込んで、ゲーム中どこからでも引けるようにする（自動読み込み: DataDB）。
## 間違いは errors に集め、起動時に出力する。数値の調整は JSON 側だけで行う。

const FILES: Dictionary = {
	"skills": "res://data/skills/skills.json",
	"supports": "res://data/supports/supports.json",
	"chains": "res://data/chains/chains.json",
	"enemies": "res://data/enemies/enemies.json",
	"rarities": "res://data/items/rarities.json",
	"bases": "res://data/items/bases.json",
	"affixes": "res://data/items/affixes.json",
}

var skills: Dictionary = {}     ## id -> SkillDef
var supports: Dictionary = {}   ## id -> SupportDef
var chains: Array[ChainRule] = []
var enemies: Dictionary = {}    ## id -> EnemyDef
var rarities: Array[RarityDef] = []  ## tier の低い順
var bases: Dictionary = {}      ## id -> ItemBaseDef
var affixes: Dictionary = {}    ## id -> AffixDef
var errors: Array[String] = []


func _ready() -> void:
	reload()
	if errors.is_empty():
		print("[DataDB] 読み込み完了: スキル%d 補助%d チェイン%d 敵%d 装備%d 付与効果%d" % [
			skills.size(), supports.size(), chains.size(), enemies.size(), bases.size(), affixes.size()])
	else:
		for e: String in errors:
			push_error("[DataDB] " + e)


func reload() -> void:
	skills.clear(); supports.clear(); chains.clear(); enemies.clear()
	rarities.clear(); bases.clear(); affixes.clear(); errors.clear()

	for d: Dictionary in _load("skills"):
		_put(skills, SkillDef.from_dict(d, errors), "skill")
	for d: Dictionary in _load("supports"):
		_put(supports, SupportDef.from_dict(d, errors), "support")
	for d: Dictionary in _load("enemies"):
		_put(enemies, EnemyDef.from_dict(d, errors), "enemy")
	for d: Dictionary in _load("bases"):
		_put(bases, ItemBaseDef.from_dict(d, errors), "item base")
	for d: Dictionary in _load("affixes"):
		_put(affixes, AffixDef.from_dict(d, errors), "affix")
	for d: Dictionary in _load("rarities"):
		rarities.append(RarityDef.from_dict(d, errors))
	rarities.sort_custom(func(a: RarityDef, b: RarityDef) -> bool: return a.tier < b.tier)
	for d: Dictionary in _load("chains"):
		chains.append(ChainRule.from_dict(d, errors))
	_check_references()


## 別のデータを指している名前が実在するか
func _check_references() -> void:
	for c: ChainRule in chains:
		if not skills.has(c.result):
			errors.append("chain %s: result「%s」が skills.json にありません" % [c.id, c.result])
		elif not (skills[c.result] as SkillDef).chain_only:
			errors.append("chain %s: result「%s」は chain_only: true にしてください" % [c.id, c.result])
		for sid: String in [c.prev_skill, c.next_skill]:
			if not sid.is_empty() and not skills.has(sid):
				errors.append("chain %s: スキル「%s」が skills.json にありません" % [c.id, sid])
		for t: String in c.prev_tags + c.next_tags:
			if not SkillDef.ELEMENTS.has(t) and not SkillDef.KINDS.has(t):
				errors.append("chain %s: タグ「%s」は属性か種類の名前にしてください" % [c.id, t])
	var beams := rarities.filter(func(r: RarityDef) -> bool: return r.beam).size()
	if beams > 2:
		errors.append("rarity: 光の柱（beam）は最上位2段階だけの方針です（今は%d段階）" % beams)


func _load(key: String) -> Array:
	var path: String = FILES[key]
	if not FileAccess.file_exists(path):
		errors.append("%s がありません" % path)
		return []
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s の %d 行目: %s" % [path, json.get_error_line(), json.get_error_message()])
		return []
	if typeof(json.data) != TYPE_ARRAY:
		errors.append("%s: 一番外側は配列 [ ... ] にしてください" % path)
		return []
	return json.data


func _put(table: Dictionary, def: Variant, label: String) -> void:
	if def.id.is_empty():
		return
	if table.has(def.id):
		errors.append("%s「%s」が2回定義されています" % [label, def.id])
	table[def.id] = def


# ---- 引くための関数 ----

func skill(id: String) -> SkillDef:
	return skills.get(id)


func support(id: String) -> SupportDef:
	return supports.get(id)


func enemy(id: String) -> EnemyDef:
	return enemies.get(id)


## ドロップするスキルジェム（チェイン専用の技は除く）
func droppable_skills() -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	for s: SkillDef in skills.values():
		if not s.chain_only:
			out.append(s)
	return out
