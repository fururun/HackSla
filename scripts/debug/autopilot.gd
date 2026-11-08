class_name Autopilot
extends RefCounted
## デバッグ用の自動戦闘（F2 で入り切り）。バランス調整や、装備・スキルの効きを、手を離して見るためのもの。
## マップの床を A*（AStarGrid2D）で歩くので、壁を避けて目的地へ行ける。
##   ルート（F3 で切り替え）：近い敵から ／ ボスへ直行
##   宝箱（F6 で切り替え）：開けに行く ／ 開けない
## 近くに敵がいれば止まって戦い、いなければ落ちているもの → 宝箱 → ルートの目的地、の順に行く。
## ボスなどの大きな攻撃の予告が出たら、回避（Space と同じ）で逃げる。

enum Route { NEAREST_ENEMY, BOSS_RUSH }
const ROUTE_NAMES: Array[String] = ["近い敵から", "ボスへ直行"]

const ENGAGE_DISTANCE: float = 26.0  ## この距離（地面）まで敵に近づいたら、止まって戦う
const FIGHT_FIRST_DISTANCE: float = 90.0  ## この距離以内に敵がいたら、拾う・宝箱より戦いを先にする（ボスへ直行のときは、先へ進む）
const DODGE_WATCH_DISTANCE: float = 150.0  ## 予告を出している敵が、この距離以内なら避ける
const CHEST_DETOUR_PATH: float = 40.0  ## 宝箱へ寄り道するのは、道のりがこのマス数以内のとき
const PATH_REFRESH_SECONDS: float = 0.5
const WAYPOINT_REACHED: float = 4.0  ## 道しるべの点に、これだけ近づいたら、次の点へ
const EDGE_WEIGHT: float = 4.0  ## 壁ぎわのマスの通りにくさ（通路の真ん中を通るようにする）
const STUCK_CHECK_SECONDS: float = 0.6
const STUCK_MOVE: float = 2.0
const DETOUR_SECONDS: float = 0.7
const NEAREST_CANDIDATES: int = 4  ## 近い敵を選ぶとき、道のりを比べる候補の数

var enabled: bool = false
var route: Route = Route.NEAREST_ENEMY
var open_chests: bool = true
var director: LootDirector  ## 落ちているものを探すため（空なら拾いに行かない）
var map: IsoMap  ## 歩ける床を調べるため（空なら、まっすぐ歩く）
var dodge_direction: Vector2 = Vector2.ZERO  ## wants_dodge が true のときの、逃げる向き
var goal_kind: String = ""  ## いま向かっているもの（表示用）：敵 / ボス / 宝箱 / 拾う

var _astar: AStarGrid2D
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _path_goal: Vector2i = Vector2i(-99999, -99999)
var _path_age: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _detour_left: float = 0.0
var _detour_sign: float = 1.0


func toggle() -> bool:
	enabled = not enabled
	_stuck_timer = 0.0
	_detour_left = 0.0
	_path.clear()
	return enabled


func cycle_route() -> void:
	route = ((route + 1) % ROUTE_NAMES.size()) as Route
	_path.clear()


func toggle_chests() -> bool:
	open_chests = not open_chests
	_path.clear()
	return open_chests


func settings_text() -> String:
	return "自動戦闘 ON　ルート: %s（F3）　宝箱: %s（F6）　F2で止める" % [ROUTE_NAMES[route], "開ける" if open_chests else "開けない"]


# ---- 床の地図（A*） ----

func _ensure_grid() -> bool:
	if _astar != null:
		return true
	if map == null or map.floor_layer == null:
		return false
	var floor_cells: Array[Vector2i] = map.floor_layer.get_used_cells()
	if floor_cells.is_empty():
		return false
	var rect := Rect2i(floor_cells[0], Vector2i.ONE)
	for c: Vector2i in floor_cells:
		rect = rect.expand(c)
	rect = rect.grow(2)
	_astar = AStarGrid2D.new()
	_astar.region = rect
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			_astar.set_point_solid(Vector2i(x, y), true)
	for c: Vector2i in floor_cells:
		var blocked: bool = map.wall_layer != null and map.wall_layer.get_cell_source_id(c) != -1
		_astar.set_point_solid(c, blocked)
		if blocked:
			continue
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if map.floor_layer.get_cell_source_id(c + offset) == -1:
				_astar.set_point_weight_scale(c, EDGE_WEIGHT)
				break
	return true


func cell_of(pos: Vector2) -> Vector2i:
	return map.floor_layer.local_to_map(map.floor_layer.to_local(pos))


func position_of(cell: Vector2i) -> Vector2:
	return map.floor_layer.to_global(map.floor_layer.map_to_local(cell))


## from から to までの道のり（マス数）。行けないときは -1
func path_length(from: Vector2, to: Vector2) -> int:
	if not _ensure_grid():
		return -1
	var path: Array[Vector2i] = _astar.get_id_path(cell_of(from), cell_of(to))
	return path.size() - 1 if not path.is_empty() else -1


# ---- 目的地を決める ----

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


func find_boss(player: Node2D) -> Node2D:
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and e.active and e.definition != null and e.definition.is_boss:
			return e
	return null


## 道のりが短い敵を選ぶ（地面の距離が近い数体だけ、道のりを比べる）
func _nearest_by_path(player: Node2D) -> Node2D:
	var candidates: Array = []
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and e.active and e.visible:
			candidates.append([Iso.ground_distance(player.global_position, e.global_position), e])
	if candidates.is_empty():
		return find_target(player)
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var best: Node2D = null
	var best_len: int = 1 << 30
	for i: int in mini(NEAREST_CANDIDATES, candidates.size()):
		var e2: Node2D = candidates[i][1]
		var length: int = path_length(player.global_position, e2.global_position)
		if length < 0:
			length = 100000  # 行けない敵は、後回し
		if length < best_len:
			best_len = length
			best = e2
	return best


func _nearest_chest(player: Node2D) -> Node2D:
	var best: Node2D = null
	var best_len: int = 1 << 30
	for node: Node in player.get_tree().get_nodes_in_group("chests"):
		var chest := node as TreasureChest
		if chest == null or chest.is_open:
			continue
		var length: int = path_length(player.global_position, chest.global_position)
		if length >= 0 and length <= CHEST_DETOUR_PATH and length < best_len:
			best_len = length
			best = chest
	return best


## 動く向き（画面上の入力と同じ。止まるなら 0）
func move_input(player: Node2D, delta: float) -> Vector2:
	_path_age += delta
	var goal_pos: Variant = null
	var stop_distance: float = ENGAGE_DISTANCE
	goal_kind = ""
	var near: Node2D = find_target(player)
	var near_d: float = Iso.ground_distance(player.global_position, near.global_position) if near != null else INF
	var fighting: bool = near != null and near_d <= FIGHT_FIRST_DISTANCE and route != Route.BOSS_RUSH
	if fighting:
		goal_pos = near.global_position
		goal_kind = "敵"
	else:
		# 落ちているもの → 宝箱 → ルートの目的地
		if director != null:
			goal_pos = director.nearest_drop_position(player.global_position)
			if goal_pos != null:
				goal_kind = "拾う"
				stop_distance = 3.0
		if goal_pos == null and open_chests:
			var chest: Node2D = _nearest_chest(player)
			if chest != null:
				goal_pos = chest.global_position
				goal_kind = "宝箱"
				stop_distance = 3.0
		if goal_pos == null:
			var target: Node2D = null
			if route == Route.BOSS_RUSH:
				target = find_boss(player)
				goal_kind = "ボス"
			if target == null:
				target = _nearest_by_path(player)
				goal_kind = "敵"
			if target != null:
				goal_pos = target.global_position
	if goal_pos == null:
		goal_kind = ""
		return Vector2.ZERO
	var goal: Vector2 = goal_pos
	if Iso.ground_distance(player.global_position, goal) <= stop_distance:
		_stuck_timer = 0.0
		return Vector2.ZERO
	return _avoid_stuck(player, _steer(player, goal), delta)


## 道しるべ（A* の経路）に沿った向き。経路がなければ、まっすぐ
func _steer(player: Node2D, goal: Vector2) -> Vector2:
	if not _ensure_grid():
		return (goal - player.global_position).normalized()
	var from_cell: Vector2i = cell_of(player.global_position)
	var to_cell: Vector2i = cell_of(goal)
	if _path.is_empty() or to_cell != _path_goal or _path_age >= PATH_REFRESH_SECONDS:
		_path = _astar.get_id_path(from_cell, to_cell)
		_path_goal = to_cell
		_path_index = 1
		_path_age = 0.0
	while _path_index < _path.size() and player.global_position.distance_to(position_of(_path[_path_index])) < WAYPOINT_REACHED:
		_path_index += 1
	if _path.size() < 2 or _path_index >= _path.size():
		return (goal - player.global_position).normalized()  # 同じマス、または経路なし：まっすぐ
	return (position_of(_path[_path_index]) - player.global_position).normalized()


## それでも壁に引っかかって動けなくなったら、しばらく横へ回り込む
func _avoid_stuck(player: Node2D, dir: Vector2, delta: float) -> Vector2:
	_stuck_timer += delta
	if _stuck_timer >= STUCK_CHECK_SECONDS:
		if player.global_position.distance_to(_last_pos) < STUCK_MOVE:
			_detour_left = DETOUR_SECONDS
			_detour_sign = -_detour_sign
			_path.clear()
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
		# 敵の正面からずれる向き（突進の帯・扇の外）へ、横に避ける
		var away: Vector2 = (player.global_position - e.global_position).normalized()
		dodge_direction = away.rotated(deg_to_rad(70.0 * _detour_sign)).normalized()
		return true
	return false
