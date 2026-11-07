class_name DamageCalc
extends RefCounted
## ダメージ計算（仮の式。調整しやすいように定数はすべてここにまとめる）
##
## 流れ：スキルの基本値（乱数で振った値）
##   → skill_damage：ステータスの「ダメージ+%」を足して掛ける
##   → 当たった相手ごとに apply_resistance（属性）か apply_armor（物理）で減らす

## 属性耐性の上限・下限（%）
const RES_CAP: float = 75.0
const RES_FLOOR: float = -100.0
## 防御の効き方：ダメージ × ダメージ ÷（ダメージ ＋ 防御 × この値）
const ARMOR_FACTOR: float = 0.5

const PHYSICAL: String = "physical"
## 属性 → その属性のダメージ+% のキー
const ELEMENT_DAMAGE_KEY: Dictionary = {
	"fire": "fire_damage_pct",
	"cold": "cold_damage_pct",
	"lightning": "lightning_damage_pct",
}
## 属性 → その属性の耐性のキー
const ELEMENT_RES_KEY: Dictionary = {
	"fire": "fire_res",
	"cold": "cold_res",
	"lightning": "lightning_res",
}


## 基本値 ×（1 +（damage_pct + その属性の *_damage_pct）÷ 100）。下限は0
static func skill_damage(skill: SkillDef, stats: StatBlock, roll: float) -> float:
	var pct := stats.get_value("damage_pct")
	var elem_key: String = ELEMENT_DAMAGE_KEY.get(skill.element, "")
	if not elem_key.is_empty():
		pct += stats.get_value(elem_key)
	return maxf(0.0, roll * (1.0 + pct / 100.0))


## 属性耐性で減らす（物理には使わない）。耐性は上限75%・下限-100%で切る
static func apply_resistance(amount: float, element: String, target_res: float) -> float:
	if element == PHYSICAL:
		return amount
	var res := clampf(target_res, RES_FLOOR, RES_CAP)
	return amount * (1.0 - res / 100.0)


## 防御で減らす（物理だけに使う）。大きな一撃ほど防御で減りにくい
static func apply_armor(amount: float, armor: float) -> float:
	if amount <= 0.0 or armor <= 0.0:
		return maxf(0.0, amount)
	return amount * amount / (amount + armor * ARMOR_FACTOR)


## 相手のステータスから、その属性の耐性を取り出す
static func resistance_of(target: StatBlock, element: String) -> float:
	var key: String = ELEMENT_RES_KEY.get(element, "")
	return 0.0 if key.is_empty() else target.get_value(key)


## 1回の攻撃の最終ダメージ（スキル・攻撃側・受ける側のステータスから）
static func final_damage(skill: SkillDef, attacker: StatBlock, target: StatBlock, roll: float) -> float:
	var dmg := skill_damage(skill, attacker, roll)
	if skill.element == PHYSICAL:
		return apply_armor(dmg, target.get_value("armor"))
	return apply_resistance(dmg, skill.element, resistance_of(target, skill.element))
