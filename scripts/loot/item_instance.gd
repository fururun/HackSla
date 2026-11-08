class_name ItemInstance
extends RefCounted
## 付与効果は {id: String, value: int} の配列。定義データは変更しない。

var base: ItemBaseDef
var rarity: RarityDef
var affixes: Array[Dictionary] = []


func total_stats() -> Dictionary:
	var stats: Dictionary = {}
	for key: String in base.stats:
		stats[key] = roundi(float(base.stats[key]) * rarity.stat_mult)
	for rolled: Dictionary in affixes:
		var affix: AffixDef = DataDB.affixes[rolled["id"]]
		stats[affix.stat] = stats.get(affix.stat, 0) + rolled["value"]
	return stats


const POWER_WEIGHTS: Dictionary = {"life": 0.5, "armor": 0.6, "area_pct": 0.8, "cooldown_pct": 0.8, "move_speed_pct": 0.7}  ## 性能の合計の重み（ほかは 1.0）


## 装備の強さの目安（性能の重みつき合計）。同じ部位で、どちらを着るか決めるのに使う
func power() -> float:
	var total: float = 0.0
	var stats: Dictionary = total_stats()
	for key: String in stats:
		total += float(stats[key]) * float(POWER_WEIGHTS.get(key, 1.0))
	return total


func display_name() -> String:
	return "%s %s" % [rarity.name, base.name]
