class_name SkillLoadout
extends RefCounted
## スキル枠（1〜6）。枠ごとに「スキルid」と「補助ジェムid（0〜1個）」を持つ。
## 装備画面（T11）は set_skill / set_support / clear_* で実行時に付け替える。

signal changed(slot: int)

const SLOT_COUNT: int = 6
const DEFAULT_SKILL_IDS: PackedStringArray = ["slash", "frost_bloom", "fire_bolt"]  ## 枠1から順

var _skill_ids: PackedStringArray = PackedStringArray()
var _support_ids: PackedStringArray = PackedStringArray()


func _init() -> void:
	_skill_ids.resize(SLOT_COUNT)
	_support_ids.resize(SLOT_COUNT)
	for i: int in DEFAULT_SKILL_IDS.size():
		_skill_ids[i] = DEFAULT_SKILL_IDS[i]


static func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


## 枠のスキルid（空なら ""）
func skill_id(slot: int) -> String:
	return _skill_ids[slot - 1] if is_valid_slot(slot) else ""


func support_id(slot: int) -> String:
	return _support_ids[slot - 1] if is_valid_slot(slot) else ""


func skill(slot: int) -> SkillDef:
	var id := skill_id(slot)
	return DataDB.skill(id) if not id.is_empty() else null


func support(slot: int) -> SupportDef:
	var id := support_id(slot)
	return DataDB.support(id) if not id.is_empty() else null


## スキルを入れる（"" で空にする）。存在しないid・範囲外の枠は false。
## 入っている補助ジェムが新しいスキルに付けられない種類なら、補助ジェムは外す。
func set_skill(slot: int, id: String) -> bool:
	if not is_valid_slot(slot):
		return false
	if not id.is_empty() and DataDB.skill(id) == null:
		return false
	_skill_ids[slot - 1] = id
	var sup := support(slot)
	if id.is_empty() or (sup != null and not sup.can_support(DataDB.skill(id))):
		_support_ids[slot - 1] = ""
	changed.emit(slot)
	return true


## 補助ジェムをはめる（"" で外す）。スキルが無い枠・存在しないid・kinds が合わないときは false。
func set_support(slot: int, id: String) -> bool:
	if not is_valid_slot(slot):
		return false
	if not id.is_empty():
		var sup := DataDB.support(id)
		var sk := skill(slot)
		if sup == null or sk == null or not sup.can_support(sk):
			return false
	_support_ids[slot - 1] = id
	changed.emit(slot)
	return true


func clear_skill(slot: int) -> bool:
	return set_skill(slot, "")


func clear_support(slot: int) -> bool:
	return set_support(slot, "")
