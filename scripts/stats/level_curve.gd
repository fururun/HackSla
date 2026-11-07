class_name LevelCurve
extends RefCounted
## 経験値とレベル。レベルアップで上がるのはスキルツリーのポイント1つだけ。

const MAX_LEVEL: int = 100
const XP_BASE: float = 20.0  ## 仮の式 XP_BASE × level^XP_EXPONENT
const XP_EXPONENT: float = 1.5
const POINTS_PER_LEVEL: int = 1


static func xp_to_next(level: int) -> int:
	return roundi(XP_BASE * pow(float(level), XP_EXPONENT))


## state = {"level", "xp", "points"} を更新し、上がったレベル数を返す
static func add_xp(state: Dictionary, amount: int) -> int:
	var level: int = int(state.get("level", 1))
	var xp: int = int(state.get("xp", 0))
	var points: int = int(state.get("points", 0))
	var gained: int = 0
	if level < MAX_LEVEL and amount > 0:
		xp += amount
		while level < MAX_LEVEL and xp >= xp_to_next(level):
			xp -= xp_to_next(level)
			level += 1
			points += POINTS_PER_LEVEL
			gained += 1
	if level >= MAX_LEVEL:
		xp = 0
	state["level"] = level
	state["xp"] = xp
	state["points"] = points
	return gained
