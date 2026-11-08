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
	"skill_tree": "res://data/skill_tree/skill_tree.json",
}
## 表示名・説明文（一番外側がオブジェクト）。案の切り替えは names.json の adopted / rarity_plan だけで行う
const TEXT_FILE: String = "res://data/text/names.json"

var skills: Dictionary = {}     ## id -> SkillDef
var supports: Dictionary = {}   ## id -> SupportDef
var chains: Array[ChainRule] = []
var enemies: Dictionary = {}    ## id -> EnemyDef
var rarities: Array[RarityDef] = []  ## tier の低い順
var bases: Dictionary = {}      ## id -> ItemBaseDef
var affixes: Dictionary = {}    ## id -> AffixDef
var tree_nodes: Dictionary = {} ## id -> TreeNodeDef（スキルツリー。JSON に書いた順）
var texts: Dictionary = {}      ## "category:id" -> TextEntry
var rarity_plan: int = 1        ## レアリティ名の案（6段階セットで切り替える）
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
	rarities.clear(); bases.clear(); affixes.clear(); tree_nodes.clear(); texts.clear(); errors.clear()

	for d: Dictionary in _load("skills"):
		_put(skills, SkillDef.from_dict(d, errors), "skill")
	for d: Dictionary in _load("supports"):
		_put(supports, SupportDef.from_dict(d, errors), "support")
	for d: Dictionary in _load("enemies"):
		_put(enemies, EnemyDef.from_dict(d, errors), "enemy")
	for d: Dictionary in _load("skill_tree"):
		_put(tree_nodes, TreeNodeDef.from_dict(d, errors), "tree node")
	for d: Dictionary in _load("bases"):
		_put(bases, ItemBaseDef.from_dict(d, errors), "item base")
	for d: Dictionary in _load("affixes"):
		_put(affixes, AffixDef.from_dict(d, errors), "affix")
	for d: Dictionary in _load("rarities"):
		rarities.append(RarityDef.from_dict(d, errors))
	rarities.sort_custom(func(a: RarityDef, b: RarityDef) -> bool: return a.tier < b.tier)
	for d: Dictionary in _load("chains"):
		chains.append(ChainRule.from_dict(d, errors))
	_load_texts()
	_check_references()
	_apply_texts()


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
	var starts: int = 0
	var used_cells: Dictionary = {}
	for node: TreeNodeDef in tree_nodes.values():
		starts += 1 if node.start else 0
		for other: String in node.links:
			if not tree_nodes.has(other):
				errors.append("tree node %s: links の「%s」が skill_tree.json にありません" % [node.id, other])
		if used_cells.has(node.pos):
			errors.append("tree node %s: 位置 %s が %s と重なっています" % [node.id, node.pos, used_cells[node.pos]])
		used_cells[node.pos] = node.id
	if not tree_nodes.is_empty() and starts < 1:
		errors.append("tree: start: true のノードが1つもありません")
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


func _load_texts() -> void:
	if not FileAccess.file_exists(TEXT_FILE):
		errors.append("%s がありません" % TEXT_FILE)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(TEXT_FILE)) != OK:
		errors.append("%s の %d 行目: %s" % [TEXT_FILE, json.get_error_line(), json.get_error_message()])
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s: 一番外側はオブジェクト { ... } にしてください" % TEXT_FILE)
		return
	var root: Dictionary = json.data
	rarity_plan = int(root.get("rarity_plan", 1))
	for d: Variant in root.get("entries", []):
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var e := TextEntry.from_dict(d, errors)
		var key := "%s:%s" % [e.category, e.id]
		if texts.has(key):
			errors.append("text「%s」が2回定義されています" % key)
		texts[key] = e


## 読み込んだ表示名・説明文を各データの name / description に反映する
func _apply_texts() -> void:
	for s: SkillDef in skills.values():
		_apply(s, text_of("skill", s.id))
	for s: SupportDef in supports.values():
		_apply(s, text_of("support", s.id))
	for en: EnemyDef in enemies.values():
		_apply(en, text_of("enemy", en.id))
	for a: AffixDef in affixes.values():
		_apply(a, text_of("affix", a.id))
	for r: RarityDef in rarities:
		_apply(r, text_of("rarity", r.id))
	for c: ChainRule in chains:
		var t: TextEntry = text_of("chain", c.id)
		_apply(c, t if t != null else text_of("skill", c.result))
	for key: String in texts:
		var e: TextEntry = texts[key]
		if e.category == "rarity":
			var r: RarityDef = rarity(e.id)
			if r == null:
				errors.append("text %s: rarities.json にありません" % key)
			elif e.rank != r.tier + 1:
				errors.append("text %s: rank %d が tier %d と合いません（rank = tier + 1）" % [key, e.rank, r.tier])
		elif e.category != "affix" and e.category != "chain" and not _exists(e.category, e.id):
			errors.append("text %s: 対応するデータがありません" % key)


func _exists(category: String, id: String) -> bool:
	match category:
		"skill": return skills.has(id)
		"support": return supports.has(id)
		"enemy": return enemies.has(id)
	return false


func _apply(def: Object, t: TextEntry) -> void:
	if t == null:
		return
	var plan: int = rarity_plan if t.category == "rarity" else 0
	def.set("name", t.display_name(plan))
	if "description" in def:
		def.set("description", t.description(plan))


func _put(table: Dictionary, def: Variant, label: String) -> void:
	if def.id.is_empty():
		return
	if table.has(def.id):
		errors.append("%s「%s」が2回定義されています" % [label, def.id])
	table[def.id] = def


# ---- 引くための関数 ----

## 表示名・説明文の1件（なければ null）
func text_of(category: String, id: String) -> TextEntry:
	return texts.get("%s:%s" % [category, id])


func rarity(id: String) -> RarityDef:
	for r: RarityDef in rarities:
		if r.id == id:
			return r
	return null


## 装備の表示名。付与効果名（接頭辞）をそのまま順に連結し、ベース名を続ける（助詞・語尾の調整はしない）
func item_display_name(base_id: String, affix_ids: Array) -> String:
	var out := ""
	for aid: Variant in affix_ids:
		var a: AffixDef = affixes.get(str(aid))
		out += a.name if a != null else ""
	var b: ItemBaseDef = bases.get(base_id)
	return out + (b.name if b != null else base_id)


func skill(id: String) -> SkillDef:
	return skills.get(id)


func support(id: String) -> SupportDef:
	return supports.get(id)


func tree_node(id: String) -> TreeNodeDef:
	return tree_nodes.get(id)


func enemy(id: String) -> EnemyDef:
	return enemies.get(id)


## ドロップするスキルジェム（チェイン専用の技は除く）
func droppable_skills() -> Array[SkillDef]:
	var out: Array[SkillDef] = []
	for s: SkillDef in skills.values():
		if not s.chain_only:
			out.append(s)
	return out
