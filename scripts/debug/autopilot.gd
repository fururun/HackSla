class_name Autopilot
extends RefCounted
## デバッグ用の自動戦闘（F2 で入り切り）。バランス調整や、装備・スキルの効きを、手を離して見るためのもの。
## いちばん近い敵へ歩いて行き、近づいたらスキルを全部使い、敵がいなければ落ちているものを拾いに行く。
## ボスなどの大きな攻撃の予告が出たら、回避（Space と同じ）で逃げる。壁に引っかかったら、少し横へ回り込む。
## 経路探索はしない（壁の向こうの敵には、うまく行けないことがある）。

const ENGAGE_DISTANCE: float = 26.0  ## この距離（地面）まで近づいたら、止まって戦う
const LOOT_PRIORITY_DISTANCE: float = 90.0  ## この距離以内に敵がいなければ、落ちているものを先に拾う
const DODGE_WATCH_DISTANCE: float = 150.0  ## 予告を出している敵が、この距離以内なら避ける
const STUCK_CHECK_SECONDS: float = 0.5
const STUCK_MOVE: float = 2.0  ## この秒数のあいだに、これだけ動かなければ、引っかかっている
const DETOUR_SECONDS: float = 0.7

var enabled: bool = false
var director: LootDirector  ## 落ちているものを探すため（空なら拾いに行かない）
var dodge_direction: Vector2 = Vector2.ZERO  ## wants_dodge が true のときの、逃げる向き

var _last_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _detour_left: float = 0.0
var _detour_sign: float = 1.0


func toggle() -> bool:
	enabled = not enabled
	_stuck_timer = 0.0
	_detour_left = 0.0
	return enabled


## いちばん近い、倒せる敵（案山子は、ほかに敵がいないときだけ）
func find_target(player: Node2D) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	var dummy: Node2D = null
	var dummy_d: float = INF
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var e := node as Node2D
		if e == null or not e.visible:
			continue
		var d: float = Iso.ground_distance(player.global_position, e.global_position)
		if e is TrainingDummy:
			if d < dummy_d:
				dummy = e
				dummy_d = d
		elif d < best_d:
			best = e
			best_d = d
	return best if best != null else dummy


## 動く向き（画面上の入力と同じ。止まるなら 0）
func move_input(player: Node2D, delta: float) -> Vector2:
	var target: Node2D = find_target(player)
	var goal: Variant = null  # Vector2 または null
	var stop_distance: float = ENGAGE_DISTANCE
	if target != null:
		var d: float = Iso.ground_distance(player.global_position, target.global_position)
		goal = target.global_position
		if director != null and d > LOOT_PRIORITY_DISTANCE:
			var loot: Variant = director.nearest_drop_position(player.global_position)
			if loot != null:
				goal = loot
				stop_distance = 3.0
	elif director != null:
		var loot2: Variant = director.nearest_drop_position(player.global_position)
		if loot2 != null:
			goal = loot2
			stop_distance = 3.0
	if goal == null:
		return Vector2.ZERO
	var to_goal: Vector2 = goal - player.global_position
	if Iso.ground_distance(player.global_position, goal) <= stop_distance:
		_stuck_timer = 0.0
		return Vector2.ZERO
	var dir: Vector2 = to_goal.normalized()
	return _avoid_stuck(player, dir, delta)


## 壁に引っかかって動けなくなったら、しばらく横へ回り込む
func _avoid_stuck(player: Node2D, dir: Vector2, delta: float) -> Vector2:
	_stuck_timer += delta
	if _stuck_timer >= STUCK_CHECK_SECONDS:
		if player.global_position.distance_to(_last_pos) < STUCK_MOVE:
			_detour_left = DETOUR_SECONDS
			_detour_sign = -_detour_sign
		_last_pos = player.global_position
		_stuck_timer = 0.0
	if _detour_left > 0.0:
		_detour_left -= delta
		return dir.rotated(deg_to_rad(80.0) * _detour_sign).normalized()
	return dir


## 近くに敵がいるあいだ、スキルを全部使う（出せるかどうかは、再使用時間などで決まる）
func wants_skill(player: Player) -> bool:
	return player.nearest_enemy() != null


## 大きな攻撃の予告（突進・叩きつけ・弾のため）が、近くで始まっていたら、避ける。向きは dodge_direction
func wants_dodge(player: Node2D) -> bool:
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or not e.active:
			continue
		var warning: bool = e.charge_phase == 1 or e.aoe_windup_left > 0.0 or e.shot_windup_left > 0.0
		if not warning:
			continue
		if Iso.ground_distance(player.global_position, e.global_position) > DODGE_WATCH_DISTANCE:
			continue
		# 敵から離れる向きではなく、敵の正面からずれる向き（突進の帯・扇の外へ）に、横へ避ける
		var away: Vector2 = (player.global_position - e.global_position).normalized()
		dodge_direction = away.rotated(deg_to_rad(70.0 * _detour_sign)).normalized()
		return true
	return false
