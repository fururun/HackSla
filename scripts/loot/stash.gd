class_name Stash
extends RefCounted
## 装備は各部位の最高 tier のみ保持する。
signal changed
signal picked_up(value: Variant)
signal equipped(slot: String, new_item: ItemInstance, old_item: ItemInstance)
signal skipped(item: ItemInstance)
signal duplicate_gem(gem: GemInstance)

const STARTING_SUPPORT_IDS: Array[String] = ["scatter", "burst_on_kill"]
const GEM_DUPLICATE_CURRENCY: int = 5

var gems: Dictionary = {}
var equipment: Dictionary[String, ItemInstance] = {}
var currency: int = 0

func _init() -> void:
	for id: String in ["slash", "frost_bloom", "fire_bolt"]:
		add_gem(GemInstance.new(GemInstance.Kind.SKILL, id))
	for id: String in STARTING_SUPPORT_IDS:
		add_gem(GemInstance.new(GemInstance.Kind.SUPPORT, id))

func has_gem(kind: GemInstance.Kind, id: String) -> bool:
	return gems.get(kind, {}).has(id)

func add_gem(gem: GemInstance) -> void:
	if has_gem(gem.kind, gem.id):
		return
	if not gems.has(gem.kind):
		gems[gem.kind] = {}
	gems[gem.kind][gem.id] = true
	changed.emit()

func collect(value: Variant) -> void:
	if value is GemInstance:
		if has_gem(value.kind, value.id):
			currency += GEM_DUPLICATE_CURRENCY
			changed.emit()
			duplicate_gem.emit(value)
		else:
			add_gem(value)
	elif value is ItemInstance:
		var item: ItemInstance = value
		var current: ItemInstance = equipment.get(item.base.slot)
		if current == null or current.rarity.tier < item.rarity.tier:
			equipment[item.base.slot] = item
			changed.emit()
			equipped.emit(item.base.slot, item, current)
		else:
			skipped.emit(item)
	elif value is int and value > 0:
		currency += value
		changed.emit()
	else:
		return
	picked_up.emit(value)

func equipment_stats() -> StatBlock:
	var result: StatBlock = StatBlock.new()
	for item: ItemInstance in equipment.values():
		var values: Dictionary = item.total_stats()
		for key: String in values:
			result.add(key, float(values[key]))
	return result
