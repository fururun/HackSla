class_name ChainRule
extends RefCounted
## スキルチェイン1つ分の定義（data/chains/chains.json の1件）。
## 直前のスキル（prev）と今のスキル（next）が合えば、今のスキルが result に変わる。

var id: String = ""
var name: String = ""
var prev_skill: String = ""
var next_skill: String = ""
var prev_tags: PackedStringArray = []
var next_tags: PackedStringArray = []
var result: String = ""
var description: String = ""


## 特定スキル同士の指定か（タグ指定より優先される）
var is_specific: bool:
	get:
		return not prev_skill.is_empty()


static func from_dict(d: Dictionary, errors: Array[String]) -> ChainRule:
	var c := ChainRule.new()
	c.id = str(d.get("id", ""))
	c.name = str(d.get("name", c.id))
	c.prev_skill = str(d.get("prev_skill", ""))
	c.next_skill = str(d.get("next_skill", ""))
	c.prev_tags = PackedStringArray(d.get("prev_tags", []))
	c.next_tags = PackedStringArray(d.get("next_tags", []))
	c.result = str(d.get("result", ""))
	c.description = str(d.get("description", ""))
	if c.id.is_empty():
		errors.append("chain: id がありません")
	var by_skill := not c.prev_skill.is_empty() or not c.next_skill.is_empty()
	var by_tags := not c.prev_tags.is_empty() or not c.next_tags.is_empty()
	if by_skill and by_tags:
		errors.append("chain %s: スキル指定とタグ指定は同時に使えません" % c.id)
	if by_skill and (c.prev_skill.is_empty() or c.next_skill.is_empty()):
		errors.append("chain %s: prev_skill と next_skill の両方が必要です" % c.id)
	if by_tags and (c.prev_tags.is_empty() or c.next_tags.is_empty()):
		errors.append("chain %s: prev_tags と next_tags の両方が必要です" % c.id)
	if not by_skill and not by_tags:
		errors.append("chain %s: 条件（スキルかタグ）がありません" % c.id)
	if c.result.is_empty():
		errors.append("chain %s: result がありません" % c.id)
	return c


func matches(prev: SkillDef, next: SkillDef) -> bool:
	if is_specific:
		return prev.id == prev_skill and next.id == next_skill
	for t: String in prev_tags:
		if not prev.tags.has(t):
			return false
	for t: String in next_tags:
		if not next.tags.has(t):
			return false
	return true
