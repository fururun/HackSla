class_name SupportDef
extends RefCounted
## 補助ジェム1つ分の定義（data/supports/supports.json の1件）。

const MODIFIER_KEYS: PackedStringArray = [
	"damage_mult", "area_mult", "cooldown_mult", "mana_mult", "projectile_count", "hop_count",
	"explode_on_kill", "explode_damage_ratio", "chain_damage_mult", "chain_area_mult",
]

var id: String = ""
var name: String = ""
var kinds: PackedStringArray = []
var modifiers: Dictionary = {}
var description: String = ""


static func from_dict(d: Dictionary, errors: Array[String]) -> SupportDef:
	var s := SupportDef.new()
	s.id = str(d.get("id", ""))
	s.name = str(d.get("name", s.id))
	s.kinds = PackedStringArray(d.get("kinds", []))
	s.modifiers = d.get("modifiers", {})
	s.description = str(d.get("description", ""))
	if s.id.is_empty():
		errors.append("support: id がありません")
	for k: String in s.kinds:
		if not SkillDef.KINDS.has(k):
			errors.append("support %s: kinds の「%s」は存在しない種類です" % [s.id, k])
	for key: String in s.modifiers:
		if not MODIFIER_KEYS.has(key):
			errors.append("support %s: modifiers の「%s」は使えないキーです（docs/data_schema.md 参照）" % [s.id, key])
		elif typeof(s.modifiers[key]) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("support %s: modifiers.%s は数値にしてください" % [s.id, key])
	return s


## このスキルに付けられるか
func can_support(skill: SkillDef) -> bool:
	return kinds.is_empty() or kinds.has(skill.kind)
