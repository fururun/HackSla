class_name LootDirector
extends Node

signal dropped(value: Variant)  ## 地面に落とした（敵・宝箱）。バランス記録用

const MAX_GROUND_DROPS: int = 256
const PICKUP_RADIUS: float = 14.0
const SCATTER_RADIUS: float = 18.0
const CURRENCY_FLIGHT_TIME: float = 0.35
const SCATTER_ATTEMPTS: int = 8
const CHEST_XP: int = 40  ## 宝箱の中身の量（敵の xp と同じ計算で、ドロップの枠数が決まる）

var is_valid_position: Callable  ## 散らす位置が置いてよい場所か（Vector2 -> bool）。空なら制限しない
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var drops_created: int = 0
var _manager: EnemyManager
var _player: Node2D
var _parent: Node2D
var _stash: Stash
var _level_provider: Callable
var _active: Array[GroundDrop] = []
var _pool: Array[GroundDrop] = []
var _roller: LootRoller

func _init() -> void:
	rng.randomize()
	_roller = LootRoller.new(rng)

func setup(manager: EnemyManager, player: Node2D, parent: Node2D, stash: Stash, level_provider: Callable) -> void:
	_disconnect_manager()
	_clear_drops()
	_manager = manager
	_player = player
	_parent = parent
	_stash = stash
	_level_provider = level_provider
	_manager.enemy_hit.connect(_on_enemy_hit)

## 落ちているものの位置を、近い順に（自動戦闘が、行けるものを選ぶのに使う）
func drop_positions_by_distance(from: Vector2) -> Array[Vector2]:
	var list: Array = []
	for drop: GroundDrop in _active:
		if drop.value == null or not drop.visible:
			continue
		list.append([Iso.ground_distance(from, drop.global_position), drop.global_position])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var result: Array[Vector2] = []
	for entry: Array in list:
		result.append(entry[1])
	return result


## 落ちているもののうち、いちばん近いものの位置（なければ null）。自動戦闘が拾いに行くのに使う
func nearest_drop_position(from: Vector2) -> Variant:
	var best: Variant = null
	var best_d: float = INF
	for drop: GroundDrop in _active:
		if drop.value == null or not drop.visible:
			continue
		var d: float = Iso.ground_distance(from, drop.global_position)
		if d < best_d:
			best_d = d
			best = drop.global_position
	return best


func _on_enemy_hit(enemy: Enemy, _amount: float, killed: bool) -> void:
	if not killed:
		return
	var level: int = int(_level_provider.call())
	for value: Variant in _roller.roll_drops(enemy.definition, level, _stash.gems):
		spawn_drop(value, _scatter_position(enemy.global_position))


## 倒した敵のまわりに散らす。壁の中や壁ぎわは避ける（is_valid_position が空なら制限しない）。
## 何度試しても置けなければ、敵がいた場所に置く
func _scatter_position(origin: Vector2) -> Vector2:
	for attempt: int in SCATTER_ATTEMPTS:
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = sqrt(rng.randf()) * SCATTER_RADIUS
		var pos: Vector2 = origin + Vector2(cos(angle), sin(angle) * 0.5) * radius
		if not is_valid_position.is_valid() or bool(is_valid_position.call(pos)):
			return pos
	return origin


## 宝箱を開けたとき。敵1体ぶんではなく、まとまった数が出る（CHEST_XP で数が決まる）
func drop_chest(at: Vector2) -> void:
	var level: int = int(_level_provider.call())
	var def := EnemyDef.new()
	def.xp = CHEST_XP
	for value: Variant in _roller.roll_drops(def, level, _stash.gems):
		spawn_drop(value, _scatter_position(at))


func spawn_drop(value: Variant, at: Vector2) -> GroundDrop:
	if _active.size() >= MAX_GROUND_DROPS:
		_recycle(_active[0])
	var drop: GroundDrop
	if _pool.is_empty():
		drop = GroundDrop.new()
		_parent.add_child(drop)
		drops_created += 1
	else:
		drop = _pool.pop_back()
	drop.activate(value, at)
	_active.append(drop)
	dropped.emit(value)
	return drop

func active_count() -> int:
	return _active.size()

func pooled_count() -> int:
	return _pool.size()

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not is_instance_valid(_player) or _stash == null:
		return
	# 逆順なら回収しても未処理要素がずれない。毎フレームの複製は不要。
	for index: int in range(_active.size() - 1, -1, -1):
		var drop: GroundDrop = _active[index]
		drop.age += delta
		drop.update_name_visibility(_player.global_position)
		if drop.value is int:
			var remaining: float = maxf(CURRENCY_FLIGHT_TIME - drop.age + delta, delta)
			drop.global_position = drop.global_position.lerp(_player.global_position, minf(delta / remaining, 1.0))
			if drop.age < CURRENCY_FLIGHT_TIME:
				continue
		elif Iso.ground_distance(drop.global_position, _player.global_position) > PICKUP_RADIUS:
			continue
		var value: Variant = drop.value
		_recycle(drop)
		_stash.collect(value)

func _recycle(drop: GroundDrop) -> void:
	_active.erase(drop)
	drop.deactivate()
	_pool.append(drop)

func _disconnect_manager() -> void:
	if is_instance_valid(_manager) and _manager.enemy_hit.is_connected(_on_enemy_hit):
		_manager.enemy_hit.disconnect(_on_enemy_hit)

func _clear_drops(deferred: bool = false) -> void:
	for drop: GroundDrop in _active + _pool:
		if is_instance_valid(drop):
			if deferred:
				drop.hide()
				drop.queue_free()
			else:
				drop.free()
	_active.clear()
	_pool.clear()

func _exit_tree() -> void:
	_disconnect_manager()
	# 親も終了中の可能性があるため、ツリーの走査中には子を外さない。
	_clear_drops(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_manager()
		_clear_drops()
