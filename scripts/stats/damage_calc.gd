class_name DamageCalc
extends RefCounted
## ダメージ計算（純粋な計算だけ）。式の定数は仮。

const RES_MAX: float = 75.0  ## 耐性の上限（%）
const RES_MIN: float = -100.0  ## 耐性の下限（%）
const PERCENT_DIV: float = 100.0
const ARMOR_FACTOR: float = 0.5  ## 防御が効く強さ（仮）
const PHYSICAL: String = "physical"
const KEY_DAMAGE_PCT: String = "damage_pct"
const KEY_ELEMENT_DAMAGE_SUFFIX: String = "_damage_pct"


## 基本値（roll）×（1 + (damage_pct + 属性の *_damage_pct) / 100）
static func skill_damage(skill: SkillDef, stats: StatBlock, roll: float) -> float:
	var pct: float = stats.get_value(KEY_DAMAGE_PCT) + stats.get_value(skill.element + KEY_ELEMENT_DAMAGE_SUFFIX)
	return roll * (1.0 + pct / PERCENT_DIV)


## 耐性%ぶん減らす。上限 RES_MAX、下限 RES_MIN。physical には使わない
static func apply_resistance(amount: float, element: String, target_res: float) -> float:
	if element == PHYSICAL:
		return amount
	var res: float = clampf(target_res, RES_MIN, RES_MAX)
	return amount * (1.0 - res / PERCENT_DIV)


## physical だけ。amount² / (amount + armor × ARMOR_FACTOR)
static func apply_armor(amount: float, armor: float) -> float:
	if amount <= 0.0:
		return 0.0
	return amount * amount / (amount + maxf(armor, 0.0) * ARMOR_FACTOR)
