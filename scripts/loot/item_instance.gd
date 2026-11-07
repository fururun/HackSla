class_name ItemInstance
extends RefCounted
## 付与効果は {id: String, value: int} の配列。定義データは変更しない。

var base: ItemBaseDef
var rarity: RarityDef
var affixes: Array[Dictionary] = []


func total_stats() -> Dictionary:
	var stats: Dictionary = base.stats.duplicate()
	for rolled: Dictionary in affixes:
		var affix: AffixDef = DataDB.affixes[rolled["id"]]
		stats[affix.stat] = stats.get(affix.stat, 0) + rolled["value"]
	return stats


func display_name() -> String:
	return "%s %s" % [rarity.name, base.name]
