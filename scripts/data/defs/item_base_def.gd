class_name ItemBaseDef
extends RefCounted
## 装備の土台1つ分の定義（data/items/bases.json の1件）。

const SLOTS: PackedStringArray = ["weapon", "armor", "helmet", "boots", "ring", "amulet"]

var id: String = ""
var name: String = ""
var slot: String = ""
var level: int = 1
var stats: Dictionary = {}


static func from_dict(d: Dictionary, errors: Array[String]) -> ItemBaseDef:
	var b := ItemBaseDef.new()
	b.id = str(d.get("id", ""))
	b.name = str(d.get("name", b.id))
	b.slot = str(d.get("slot", ""))
	b.level = int(d.get("level", 1))
	b.stats = d.get("stats", {})
	if b.id.is_empty():
		errors.append("item base: id がありません")
	if not SLOTS.has(b.slot):
		errors.append("item base %s: slot「%s」は %s のどれかにしてください" % [b.id, b.slot, ", ".join(SLOTS)])
	for key: String in b.stats:
		if not AffixDef.STATS.has(key):
			errors.append("item base %s: stats の「%s」は使えないキーです" % [b.id, key])
	return b
