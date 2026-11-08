class_name Autopilot
extends RefCounted
## デバッグ用の自動戦闘（F2 で入り切り）。バランス調整や、装備・スキルの効きを、手を離して見るためのもの。
## マップの床を A*（AStarGrid2D）で歩くので、壁を避けて目的地へ行ける。
##   ルート（F3 で切り替え）：近い敵から ／ ボスへ直行
##   宝箱（F6 で切り替え）：開けに行く ／ 開けない
## 近くに敵がいれば止まって戦い、いなければ落ちているもの → 宝箱 → ルートの目的地、の順に行く。
## ボスなどの大きな攻撃の予告が出たら、回避（Space と同じ）で逃げる。

enum Route { NEAREST_ENEMY, BOSS_RUSH }
const ROUTE_NAMES: Array[String] = ["敵を全滅（ボスは最後）", "ボスへ直行"]
const HEAL_BELOW_RATIO: float = 0.2  ## ライフがこの割合以下（残り2割）になったら、回復を使う
const BOSS_AVOID_DISTANCE: float = 270.0  ## 全滅ルートでは、まだ眠っているボスのこの距離（地面）以内には、ほかの敵が残っているあいだ近づかない（起こしてしまうので）

const ENGAGE_DISTANCE: float = 26.0  ## この距離（地面）まで敵に近づいたら、止まって戦う
const FIGHT_FIRST_DISTANCE: float = 90.0  ## この距離以内に敵がいたら、拾う・宝箱より戦いを先にする（ボスへ直行のときは、先へ進む）
const DODGE_WATCH_DISTANCE: float = 150.0  ## 予告を出している敵が、この距離以内なら避ける
const CHEST_DETOUR_PATH: float = 40.0  ## 宝箱へ寄り道するのは、道のりがこのマス数以内のとき
const CHEST_NEARBY_PATH: float = 14.0  ## 全滅ルートでも、通り道のこのマス数以内の宝箱は、敵より先に開ける（素通りしない）
const PATH_REFRESH_SECONDS: float = 0.5
const WAYPOINT_REACHED: float = 4.0  ## 道しるべの点に、これだけ近づいたら、次の点へ
const EDGE_WEIGHT: float = 4.0  ## 壁ぎわのマスの通りにくさ（通路の真ん中を通るようにする）
const STUCK_CHECK_SECONDS: float = 0.6
const STUCK_MOVE: float = 2.0
const DETOUR_SECONDS: float = 0.7
const MAX_PICKUP_PATH: float = 80.0  ## 拾いに行くのは、道のりがこのマス数以内のものだけ
const MAX_STUCK_BEFORE_GIVE_UP: int = 3  ## 同じ目的地で、これだけ引っかかったら、あきらめる
const IGNORE_SECONDS: float = 30.0  ## あきらめた目的地を、この秒数のあいだ、選ばない
const NEAREST_CANDIDATES: int = 8  ## 近い敵を選ぶとき、道のりを比べる候補の数

## スキルの回し方。標準は ALL_READY（出せるものを、全部、枠の順に出す）。
## 20秒の案山子で測ったDPSは、ALL_READY が最も高かった（161）。チェインを優先する CHAIN_PRIORITY（147）と CHAIN_GREEDY（154）は、
## 「霜囲い→払い」のようなチェインを狙って、「火の矢→霜囲い（蒸気の爆発）」の、もっと強いチェインを崩すので、かえって低い。
## ほかの構成で試したいときのために、残してある（Autopilot.skill_mode を変える）
enum SkillMode { ALL_READY, CHAIN_PRIORITY, CHAIN_GREEDY }
var skill_mode: SkillMode = SkillMode.ALL_READY
var chain_wait_seconds: float = 0.0  ## チェインの相棒の再使用まで、この秒数以内なら、ほかのスキルを出さずに待つ（0 なら待たない）
static var resume: Dictionary = {}  ## やり直し（シーンの作り直し）をまたいで、自動戦闘の設定を持ち越す
static var runs: int = 0  ## 自動でやり直した回数（周回の数）
var auto_support: bool = true  ## 補助ジェムを、持っているものから、自動でつける（F7 で入り切り）
var stash: Stash  ## 持っている補助ジェムを調べるため
var enabled: bool = false
var route: Route = Route.NEAREST_ENEMY
var open_chests: bool = true
var director: LootDirector  ## 落ちているものを探すため（空なら拾いに行かない）
var map: IsoMap  ## 歩ける床を調べるため（空なら、まっすぐ歩く）
var dodge_direction: Vector2 = Vector2.ZERO  ## wants_dodge が true のときの、逃げる向き
var cleared: bool = false  ## 倒せる敵が、もういない
var goal_kind: String = ""  ## いま向かっているもの（表示用）：敵 / ボス / 宝箱 / 拾う

var _clock: float = 0.0
var _ignored: Dictionary = {}  ## 目的地のマス -> あきらめを解く時刻（行けない・引っかかり続ける場所）
var _stuck_count: int = 0
var _current_goal_cell: Vector2i = Vector2i(-99999, -99999)
var _astar: AStarGrid2D
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _path_goal: Vector2i = Vector2i(-99999, -99999)
var _path_age: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
var _detour_left: float = 0.0
var _detour_sign: float = 1.0


## やり直す前に呼ぶ。自動戦闘が入っていれば、その設定を覚える（入っていなければ、覚えを消す）
func save_state() -> void:
	if enabled:
		resume = {"route": route, "chests": open_chests, "support": auto_support}
	else:
		resume = {}
		runs = 0


## 作り直した画面で呼ぶ。覚えがあれば、設定を戻して、自動戦闘を入れる。入れたら true
func load_state() -> bool:
	if resume.is_empty():
		return false
	route = int(resume.get("route", route)) as Route
	open_chests = bool(resume.get("chests", open_chests))
	auto_support = bool(resume.get("support", auto_support))
	enabled = true
	return true


func toggle() -> bool:
	enabled = not enabled
	_ignored.clear()
	_stuck_count = 0
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


## 補助ジェムの良さ（その枠のスキルに付けたときの、おおよその強さ。1.0 が、付けないとき）。
## ダメージ ÷ 再使用時間の倍率に、弾の数・範囲・跳ね返り・撃破時の爆発（群れで効く分）を足す
static func support_score(support: SupportDef) -> float:
	var m: Dictionary = support.modifiers
	var damage: float = float(m.get("damage_mult", 1.0))
	var cooldown: float = maxf(float(m.get("cooldown_mult", 1.0)), 0.1)
	var score: float = damage / cooldown
	score *= 1.0 + 0.4 * float(m.get("projectile_count", 0))
	score *= 1.0 + 0.8 * (float(m.get("area_mult", 1.0)) - 1.0)
	score *= 1.0 + 0.15 * float(m.get("hop_count", 0))
	score *= 1.0 + 0.3 * float(m.get("explode_on_kill", 0.0)) * float(m.get("explode_damage_ratio", 0.0))
	return score


## 持っている補助ジェムのうち、その枠のスキルに付けられて、いちばん良いものを、各枠につける。
## いま付いているものより良いときだけ、付け替える。付け替えた数を返す
func equip_supports(caster: SkillCaster) -> int:
	if stash == null:
		return 0
	var changed: int = 0
	for slot: int in range(1, SkillLoadout.SLOT_COUNT + 1):
		var skill: SkillDef = caster.loadout.skill(slot)
		if skill == null:
			continue
		var current: SupportDef = caster.loadout.support(slot)
		var best: SupportDef = current
		var best_score: float = support_score(current) if current != null else 1.0
		for support: SupportDef in DataDB.supports.values():
			if not support.can_support(skill) or not stash.has_gem(GemInstance.Kind.SUPPORT, support.id):
				continue
			var score: float = support_score(support)
			if score > best_score + 0.0001:
				best = support
				best_score = score
		if best != current and best != null and caster.loadout.set_support(slot, best.id):
			changed += 1
	return changed


func settings_text() -> String:
	var head: String = "自動戦闘：敵を全滅させた" if cleared else "自動戦闘 ON"
	if runs > 0:
		head += "（%d周目）" % (runs + 1)
	return "%s　ルート: %s（F3）　宝箱: %s（F6）　補助: %s（F7）　F2で止める" % [head, ROUTE_NAMES[route], "開ける" if open_chests else "開けない", "自動" if auto_support else "手動"]


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
	var from_cell: Vector2i = cell_of(from)
	var to_cell: Vector2i = cell_of(to)
	if not _astar.is_in_boundsv(from_cell) or not _astar.is_in_boundsv(to_cell):
		return -1  # 地図の外
	var path: Array[Vector2i] = _astar.get_id_path(from_cell, to_cell)
	return path.size() - 1 if not path.is_empty() else -1


func _is_ignored(pos: Vector2) -> bool:
	if map == null or map.floor_layer == null:
		return false
	var cell: Vector2i = cell_of(pos)
	return _ignored.has(cell) and float(_ignored[cell]) > _clock


func _give_up(pos: Vector2) -> void:
	if map == null or map.floor_layer == null:
		return
	_ignored[cell_of(pos)] = _clock + IGNORE_SECONDS
	_path.clear()
	_stuck_count = 0


## 行ける場所か（床の上で、道がつながっていて、あきらめていない）
func _reachable(from: Vector2, to: Vector2, max_path: float = 100000.0) -> bool:
	if _is_ignored(to):
		return false
	var length: int = path_length(from, to)
	return length >= 0 and float(length) <= max_path


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
func _nearest_by_path(player: Node2D, include_boss: bool = true) -> Node2D:
	var candidates: Array = []
	var boss_candidates: Array = []
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and e.active and e.visible:
			var entry: Array = [Iso.ground_distance(player.global_position, e.global_position), e]
			if e.definition != null and e.definition.is_boss:
				boss_candidates.append(entry)  # ボスは、ほかの敵を倒しきってから
			elif not _in_boss_zone(player, e.global_position):
				candidates.append(entry)
	if candidates.is_empty() and include_boss:
		candidates = boss_candidates
	if candidates.is_empty():
		return find_target(player) if include_boss else null
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var best: Node2D = null
	var best_len: int = 1 << 30
	for i: int in mini(NEAREST_CANDIDATES, candidates.size()):
		var e2: Node2D = candidates[i][1]
		var length: int = path_length(player.global_position, e2.global_position)
		if length < 0 or _is_ignored(e2.global_position):
			length = 100000  # 行けない・あきらめた敵は、後回し
		if length < best_len:
			best_len = length
			best = e2
	if best != null and best_len >= 100000:
		return null  # 候補がみな行けない
	return best


func _nearest_chest(player: Node2D, max_path: float = -1.0) -> Node2D:
	var limit: float = max_path
	if limit < 0.0:
		limit = CHEST_DETOUR_PATH if route == Route.BOSS_RUSH else 100000.0  # 全滅ルートは、どれだけ遠くても開けに行く
	var best: Node2D = null
	var best_len: int = 1 << 30
	for node: Node in player.get_tree().get_nodes_in_group("chests"):
		var chest := node as TreasureChest
		if chest == null or chest.is_open or _in_boss_zone(player, chest.global_position) or _is_ignored(chest.global_position):
			continue
		var length: int = path_length(player.global_position, chest.global_position)
		if length >= 0 and float(length) <= limit and length < best_len:
			best_len = length
			best = chest
	return best


## 動く向き（画面上の入力と同じ。止まるなら 0）
func move_input(player: Node2D, delta: float) -> Vector2:
	_path_age += delta
	_clock += delta
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
			goal_pos = null
			for drop_pos: Vector2 in director.drop_positions_by_distance(player.global_position):
				if _in_boss_zone(player, drop_pos) or not _reachable(player.global_position, drop_pos, MAX_PICKUP_PATH):
					continue  # ボスの近く・壁の中・遠回りのものは、拾いに行かない
				goal_pos = drop_pos
				break
			if goal_pos != null:
				goal_kind = "拾う"
				stop_distance = 3.0
		# 全滅ルート：近くの宝箱 → ボス以外の敵を全部倒す → 遠くの宝箱 → ボス。ボスへ直行：宝箱（寄り道）→ ボス
		if goal_pos == null and open_chests and route == Route.NEAREST_ENEMY:
			var near_chest: Node2D = _nearest_chest(player, CHEST_NEARBY_PATH)
			if near_chest != null:
				goal_pos = near_chest.global_position
				goal_kind = "宝箱"
				stop_distance = 3.0
		if goal_pos == null and route == Route.NEAREST_ENEMY:
			var enemy: Node2D = _nearest_by_path(player, false)
			if enemy != null:
				goal_pos = enemy.global_position
				goal_kind = "敵"
		if goal_pos == null and open_chests:
			var chest: Node2D = _nearest_chest(player)
			if chest != null:
				goal_pos = chest.global_position
				goal_kind = "宝箱"
				stop_distance = 3.0
		if goal_pos == null:
			var target: Node2D = find_boss(player)
			goal_kind = "ボス"
			if target == null:
				target = _nearest_by_path(player)
				goal_kind = "敵"
			if target != null:
				goal_pos = target.global_position
	cleared = _count_enemies(player) == 0
	if goal_pos == null:
		goal_kind = ""
		return Vector2.ZERO
	var goal: Vector2 = goal_pos
	if map != null and map.floor_layer != null:
		var goal_cell: Vector2i = cell_of(goal)
		if goal_cell != _current_goal_cell:
			_current_goal_cell = goal_cell
			_stuck_count = 0
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
	if _path.is_empty() and from_cell != to_cell:
		_give_up(goal)  # 道がない（壁の中・島）：この目的地はあきらめる
		return Vector2.ZERO
	if _path.size() < 2 or _path_index >= _path.size():
		return (goal - player.global_position).normalized()  # 同じマス：まっすぐ
	return (position_of(_path[_path_index]) - player.global_position).normalized()


## それでも壁に引っかかって動けなくなったら、しばらく横へ回り込む
func _avoid_stuck(player: Node2D, dir: Vector2, delta: float) -> Vector2:
	_stuck_timer += delta
	if _stuck_timer >= STUCK_CHECK_SECONDS:
		if player.global_position.distance_to(_last_pos) < STUCK_MOVE:
			_detour_left = DETOUR_SECONDS
			_detour_sign = -_detour_sign
			_path.clear()
			_stuck_count += 1
			if _stuck_count >= MAX_STUCK_BEFORE_GIVE_UP and map != null:
				_give_up(position_of(_current_goal_cell))  # 何度も引っかかる目的地は、しばらくあきらめる
		else:
			_stuck_count = 0
		_last_pos = player.global_position
		_stuck_timer = 0.0
	if _detour_left > 0.0:
		_detour_left -= delta
		return dir.rotated(deg_to_rad(80.0) * _detour_sign).normalized()
	return dir


## ボスの部屋のまわりか（全滅ルートでは、ボスを倒すまで、ここの宝箱・ドロップには寄らない。ボスを起こさないため。部屋の宝箱は、倒した先のごほうび）
func _in_boss_zone(player: Node2D, pos: Vector2) -> bool:
	if route != Route.NEAREST_ENEMY:
		return false
	var boss: Node2D = find_boss(player)
	if boss == null:
		return false  # ボスを倒したあとは、ボスの部屋の宝箱も開ける
	return Iso.ground_distance(pos, boss.global_position) <= BOSS_AVOID_DISTANCE


## 倒せる敵（案山子を除く）の数
func _count_enemies(player: Node2D) -> int:
	var count: int = 0
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and e.active:
			count += 1
	return count


## ライフが2割減ったら、回復を使う（残り回数があるときだけ）
func wants_heal(player: Player) -> bool:
	var vitals: PlayerVitals = player.vitals
	return vitals.heal_charges > 0 and not vitals.is_dead() and vitals.life <= vitals.max_life() * HEAL_BELOW_RATIO


## このフレームに出すスキルの枠。ALL_READY は、出せるものを全部（枠の順）。CHAIN_PRIORITY は、pick_skill_slot の1つだけ
func skills_to_cast(player: Player) -> Array[int]:
	var slots: Array[int] = []
	if skill_mode == SkillMode.ALL_READY:
		for slot: int in range(1, SkillLoadout.SLOT_COUNT + 1):
			if player.caster.loadout.skill(slot) != null and player.caster.cooldown_left(slot) <= 0.0:
				slots.append(slot)
		return _within_mana(player, slots)
	if skill_mode == SkillMode.CHAIN_GREEDY:
		return _greedy_order(player)
	var pick: int = pick_skill_slot(player)
	if pick > 0:
		slots.append(pick)
	return slots


## マナで払える範囲に絞る。足りるなら、そのまま（枠の順）。足りないときは、マナあたりのダメージが大きいものから、払える分だけ出す
func _within_mana(player: Player, slots: Array[int]) -> Array[int]:
	var caster: SkillCaster = player.caster
	var total: float = 0.0
	for slot: int in slots:
		total += caster.mana_cost(slot)
	var mana: float = player.vitals.mana
	if total <= mana + 0.0001:
		return slots
	var ranked: Array[int] = slots.duplicate()
	ranked.sort_custom(func(a: int, b: int) -> bool:
		return _efficiency(caster, a) > _efficiency(caster, b))
	var chosen: Array[int] = []
	for slot: int in ranked:
		var cost: float = caster.mana_cost(slot)
		if cost <= mana + 0.0001:
			chosen.append(slot)
			mana -= cost
	return chosen


## マナ1あたりの、ダメージ（平均）。コストが0なら、とても大きい
func _efficiency(caster: SkillCaster, slot: int) -> float:
	var cost: float = caster.mana_cost(slot)
	var skill: SkillDef = caster.loadout.skill(slot)
	if skill == null:
		return 0.0
	return skill.average_damage() / cost if cost > 0.0 else 1000000.0


## 出せるスキルを全部、チェインが成立する順に並べる（出せるものを減らさない）。
## 1つ決めるたびに、「直前のスキル」が変わったものとして、次を決める
func _greedy_order(player: Player) -> Array[int]:
	var caster: SkillCaster = player.caster
	var rules: Array[ChainRule] = DataDB.chains
	var order: Array[int] = []
	var remaining: Array[int] = []
	for slot: int in range(1, SkillLoadout.SLOT_COUNT + 1):
		if caster.loadout.skill(slot) != null and caster.cooldown_left(slot) <= 0.0:
			remaining.append(slot)
	var last: SkillDef = caster.chain.last_skill
	while not remaining.is_empty():
		var chosen: int = -1
		# 完成させるスキル
		if last != null:
			for slot: int in remaining:
				if ChainTracker.find_rule(last, caster.loadout.skill(slot), rules) != null:
					chosen = slot
					break
		# 1発目になれるスキル（相棒が、この中にいる）
		if chosen < 0:
			for slot: int in remaining:
				for other: int in remaining:
					if other != slot and ChainTracker.find_rule(caster.loadout.skill(slot), caster.loadout.skill(other), rules) != null:
						chosen = slot
						break
				if chosen >= 0:
					break
		if chosen < 0:
			chosen = remaining[0]
		order.append(chosen)
		remaining.erase(chosen)
		var skill: SkillDef = caster.loadout.skill(chosen)
		var rule: ChainRule = ChainTracker.find_rule(last, skill, rules)
		last = null if rule != null else skill  # チェインが出たら、数え直し（企画書の2段階まで）
	return order


## 次に出すスキルの枠（出せるものがなければ 0）。チェインを優先する：
##   1) 出せば、チェインが成立するスキル（直前のスキルと組み合わさる）があれば、それを出す
##   2) 直前のスキルの相棒が、もうすぐ（CHAIN_WAIT_SECONDS 以内に）使えるなら、ほかのスキルは出さずに待つ
##   3) 相棒（チェインの2発目になるスキル）が、出せる状態でいる、チェインの1発目になれるスキルを出す
##   4) なければ、出せるスキルのうち、枠の番号が小さいもの
func pick_skill_slot(player: Player) -> int:
	var caster: SkillCaster = player.caster
	var rules: Array[ChainRule] = DataDB.chains
	var last: SkillDef = caster.chain.last_skill
	var ready: Array[int] = []
	for slot: int in range(1, SkillLoadout.SLOT_COUNT + 1):
		if caster.loadout.skill(slot) != null and caster.cooldown_left(slot) <= 0.0 and player.vitals.can_afford(caster.mana_cost(slot)):
			ready.append(slot)
	# 1) チェインを完成させる
	if last != null:
		for slot: int in ready:
			if ChainTracker.find_rule(last, caster.loadout.skill(slot), rules) != null:
				return slot
		# 2) 相棒がもうすぐ使えるなら、待つ
		for slot: int in range(1, SkillLoadout.SLOT_COUNT + 1):
			var partner: SkillDef = caster.loadout.skill(slot)
			if partner == null or ready.has(slot):
				continue
			if caster.cooldown_left(slot) <= chain_wait_seconds and ChainTracker.find_rule(last, partner, rules) != null:
				return 0
	if ready.is_empty():
		return 0
	# 3) チェインの1発目になれるスキル（相棒がすぐ使える）
	for slot: int in ready:
		var starter: SkillDef = caster.loadout.skill(slot)
		for other: int in range(1, SkillLoadout.SLOT_COUNT + 1):
			if other == slot or caster.loadout.skill(other) == null:
				continue
			if caster.cooldown_left(other) <= maxf(chain_wait_seconds, 0.0) and ChainTracker.find_rule(starter, caster.loadout.skill(other), rules) != null:
				return slot
	# 4) ふつうに
	return ready[0]


## 近くに敵がいるあいだ、スキルを使う（どれを出すかは pick_skill_slot）（出せるかどうかは、再使用時間などで決まる）
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
