class_name LevelCurve
extends RefCounted
## 経験値とレベル（仮の式）
## レベルが上がってもステータスは上がらない。もらえるのはスキルツリーのポイントだけ（1レベルにつき1）。

const MAX_LEVEL: int = 100
const XP_BASE: float = 20.0
const XP_EXPONENT: float = 1.5
const POINTS_PER_LEVEL: int = 1


## 状態の初期値 {"level", "xp", "points"}
static func new_state() -> Dictionary:
	return {"level": 1, "xp": 0, "points": 0}


## 今のレベルから次のレベルまでに必要な経験値。最大レベルでは0
static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return roundi(XP_BASE * pow(float(level), XP_EXPONENT))


## 経験値を足す。余りは次のレベルへ繰り越す。上がったレベル数を返す
## 最大レベルに着いたら、それ以上の経験値は捨てる
static func add_xp(state: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	var gained := 0
	state["xp"] = int(state.get("xp", 0)) + amount
	while int(state["level"]) < MAX_LEVEL and int(state["xp"]) >= xp_to_next(int(state["level"])):
		state["xp"] = int(state["xp"]) - xp_to_next(int(state["level"]))
		state["level"] = int(state["level"]) + 1
		state["points"] = int(state.get("points", 0)) + POINTS_PER_LEVEL
		gained += 1
	if int(state["level"]) >= MAX_LEVEL:
		state["xp"] = 0
	return gained


## レベル1から最大レベルまでに必要な経験値の合計（調整用）
static func total_xp_to_max() -> int:
	var total := 0
	for lv in range(1, MAX_LEVEL):
		total += xp_to_next(lv)
	return total
