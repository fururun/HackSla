class_name AffixDef
extends RefCounted
## 付与効果1つ分の定義（data/items/affixes.json の1件）。

const STATS: PackedStringArray = [
	"life", "armor", "damage_pct", "fire_damage_pct", "cold_damage_pct", "lightning_damage_pct",
	"cast_speed_pct", "move_speed_pct", "area_pct", "cooldown_pct",
	"fire_res", "cold_res", "lightning_res", "life_on_kill", "mana", "mana_regen",
]

var id: String = ""
var name: String = ""
var stat: String = ""
var value_min: float = 0.0
var value_max: float = 0.0
var weight: float = 0.0
var slots: PackedStringArray = []


static func from_dict(d: Dictionary, errors: Array[String]) -> AffixDef:
	var a := AffixDef.new()
	a.id = str(d.get("id", ""))
	a.name = str(d.get("name", a.id))
	a.stat = str(d.get("stat", ""))
	var v: Array = d.get("value", [0, 0])
	if v.size() == 2:
		a.value_min = float(v[0])
		a.value_max = float(v[1])
	a.weight = float(d.get("weight", 0))
	a.slots = PackedStringArray(d.get("slots", []))
	if a.id.is_empty():
		errors.append("affix: id がありません")
	if not STATS.has(a.stat):
		errors.append("affix %s: stat「%s」は使えないキーです（docs/data_schema.md 参照）" % [a.id, a.stat])
	for s: String in a.slots:
		if not ItemBaseDef.SLOTS.has(s):
			errors.append("affix %s: slots の「%s」は存在しない部位です" % [a.id, s])
	return a


func can_roll_on(slot: String) -> bool:
	return slots.is_empty() or slots.has(slot)
