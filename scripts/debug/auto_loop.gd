class_name AutoLoop
extends Node
## 自動戦闘の周回：ボスを倒したら、少し待って（ドロップを拾う時間）、自動でやり直し（F5 と同じ）、また最初から戦う。
## やられたときも、少し待って、やり直す（止まってしまわないように）。F2 で自動戦闘を止めれば、周回も止まる。

signal restart_requested(reason: String, run: int)

const BOSS_WAIT_SECONDS: float = 12.0  ## ボスを倒してから、やり直すまで（ボスの宝・ドロップを拾う時間）
const DEATH_WAIT_SECONDS: float = 3.0  ## やられてから、やり直すまで

var autopilot: Autopilot
var _left: float = -1.0
var _reason: String = ""


func setup(manager: EnemyManager, player: Player, pilot: Autopilot) -> void:
	autopilot = pilot
	manager.enemy_hit.connect(_on_enemy_hit)
	player.vitals.died.connect(func() -> void: _start("death", DEATH_WAIT_SECONDS))


func _on_enemy_hit(enemy: Enemy, _amount: float, killed: bool) -> void:
	if killed and enemy.definition != null and enemy.definition.is_boss:
		_start("boss", BOSS_WAIT_SECONDS)


func _start(reason: String, seconds: float) -> void:
	if autopilot == null or not autopilot.enabled:
		return  # 手で遊んでいるときは、勝手にやり直さない
	if _left >= 0.0 and _reason == "boss" and reason == "death":
		return  # ボスを倒したあとは、そのまま、やり直しを待つ
	_left = seconds
	_reason = reason


func is_waiting() -> bool:
	return _left >= 0.0


func seconds_left() -> float:
	return _left


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if _left < 0.0:
		return
	if autopilot == null or not autopilot.enabled:
		_left = -1.0  # F2 で止めたら、周回もやめる
		return
	_left -= delta
	if _left <= 0.0:
		var reason: String = _reason
		_left = -1.0
		_reason = ""
		Autopilot.runs += 1
		restart_requested.emit(reason, Autopilot.runs)
