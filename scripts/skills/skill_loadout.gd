class_name SkillLoadout
extends RefCounted
## スキル枠（1〜6）。枠ごとに「スキルid」と「補助ジェムid（0〜1個）」を持つ。
## 装備画面（T11）は set_skill / set_support / clear_* で実行時に付け替える。

signal changed(slot: int)

const SLOT_COUNT: int = 6
const MAX_SUPPORTS: int = 3  ## 1つの枠にはめられる補助ジェムの最大（スキルごとの support_slots で、さらに絞られる）
const DEFAULT_SKILL_IDS: PackedStringArray = ["slash", "frost_bloom", "fire_bolt"]  ## 枠1から順

var _skill_ids: PackedStringArray = PackedStringArray()
var _support_ids: Array[PackedStringArray] = []  ## 枠ごとの、補助ジェムのid（MAX_SUPPORTS 個ぶん。空は ""）


func _init() -> void:
	_skill_ids.resize(SLOT_COUNT)
	for i: int in SLOT_COUNT:
		var ids := PackedStringArray()
		ids.resize(MAX_SUPPORTS)
		_support_ids.append(ids)
	for i: int in DEFAULT_SKILL_IDS.size():
		_skill_ids[i] = DEFAULT_SKILL_IDS[i]


static func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


## 枠のスキルid（空なら ""）
func skill_id(slot: int) -> String:
	return _skill_ids[slot - 1] if is_valid_slot(slot) else ""


## 枠の補助ジェムのid（index は 0 から。空なら ""）
func support_id(slot: int, index: int = 0) -> String:
	if not is_valid_slot(slot) or index < 0 or index >= MAX_SUPPORTS:
		return ""
	return _support_ids[slot - 1][index]


## 枠の補助ジェムのid（MAX_SUPPORTS 個ぶん。空は ""）。保存・引き継ぎ用
func support_ids(slot: int) -> Array[String]:
	var out: Array[String] = []
	for index: int in MAX_SUPPORTS:
		out.append(support_id(slot, index))
	return out


## この枠のスキルに、補助ジェムをはめられる数（スキルがなければ 0）
func support_capacity(slot: int) -> int:
	var sk := skill(slot)
	return clampi(sk.support_slots, 1, MAX_SUPPORTS) if sk != null else 0


func skill(slot: int) -> SkillDef:
	var id := skill_id(slot)
	return DataDB.skill(id) if not id.is_empty() else null


func support(slot: int, index: int = 0) -> SupportDef:
	var id := support_id(slot, index)
	return DataDB.support(id) if not id.is_empty() else null


## はめてある補助ジェム（空の穴は除く）
func supports(slot: int) -> Array[SupportDef]:
	var out: Array[SupportDef] = []
	for index: int in MAX_SUPPORTS:
		var sup := support(slot, index)
		if sup != null:
			out.append(sup)
	return out


## スキルを入れる（"" で空にする）。存在しないid・範囲外の枠は false。
## 入っている補助ジェムが新しいスキルに付けられない種類なら、補助ジェムは外す。
func set_skill(slot: int, id: String) -> bool:
	if not is_valid_slot(slot):
		return false
	if not id.is_empty() and DataDB.skill(id) == null:
		return false
	_skill_ids[slot - 1] = id
	var new_skill: SkillDef = DataDB.skill(id) if not id.is_empty() else null
	for index: int in MAX_SUPPORTS:  # 数が減ったとき・付けられない種類のときは、外す
		var sup := support(slot, index)
		if new_skill == null or index >= new_skill.support_slots or (sup != null and not sup.can_support(new_skill)):
			_support_ids[slot - 1][index] = ""
	changed.emit(slot)
	return true


## 補助ジェムをはめる（"" で外す）。index は 0 から。スキルが無い枠・存在しないid・kinds が合わない・
## 穴の数を超える・同じ枠にもう同じ補助ジェムがある、ときは false。
func set_support(slot: int, id: String, index: int = 0) -> bool:
	if not is_valid_slot(slot) or index < 0 or index >= MAX_SUPPORTS:
		return false
	if not id.is_empty():
		var sup := DataDB.support(id)
		var sk := skill(slot)
		if sup == null or sk == null or not sup.can_support(sk) or index >= support_capacity(slot):
			return false
		for other: int in MAX_SUPPORTS:
			if other != index and support_id(slot, other) == id:
				return false
	_support_ids[slot - 1][index] = id
	changed.emit(slot)
	return true


func clear_skill(slot: int) -> bool:
	return set_skill(slot, "")


func clear_support(slot: int, index: int = 0) -> bool:
	return set_support(slot, "", index)
