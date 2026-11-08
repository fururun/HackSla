class_name PlayerVitals
extends RefCounted
## プレイヤーの体力・死亡・経験値とレベル。stats は Player の caster.stats を共有する。

signal changed
signal leveled_up(level: int)
signal died

var stats: StatBlock = StatBlock.new()
var life: float = PlayerConsts.BASE_MAX_LIFE
var level: int = 1
var xp: int = 0
var points: int = 0  ## スキルツリーのポイント（今は数えるだけ）
var _invuln: float = 0.0
var _dead: bool = false


func _init(p_stats: StatBlock = null) -> void:
	if p_stats != null:
		stats = p_stats
	life = max_life()


func max_life() -> float:
	return PlayerConsts.BASE_MAX_LIFE + stats.get_value("life")


func is_dead() -> bool:
	return _dead


## 無敵時間を進める（Player の _physics_process から呼ぶ）
func tick(delta: float) -> void:
	if _invuln > 0.0:
		_invuln = maxf(_invuln - delta, 0.0)


## 物理ダメージを受ける。実際に引かれた値を返す（死亡後・無敵中は 0）
func take_damage(amount: float) -> float:
	if _dead or _invuln > 0.0 or amount <= 0.0:
		return 0.0
	var dealt: float = minf(DamageCalc.apply_armor(amount, stats.get_value("armor")), life)
	life -= dealt
	_invuln = PlayerConsts.HIT_INVULN
	if life <= 0.0:
		life = 0.0
		_dead = true
		changed.emit()
		died.emit()
	else:
		changed.emit()
	return dealt


func grant_xp(amount: int) -> void:
	if _dead:
		return
	var state: Dictionary = {"level": level, "xp": xp, "points": points}
	var gained: int = LevelCurve.add_xp(state, amount)
	level = int(state["level"])
	xp = int(state["xp"])
	points = int(state["points"])
	if gained > 0:
		life = max_life()
	changed.emit()
	if gained > 0:
		leveled_up.emit(level)


func reset() -> void:
	level = 1
	xp = 0
	points = 0
	_invuln = 0.0
	_dead = false
	life = max_life()
	changed.emit()
