class_name LootDirector
extends Node

const MAX_GROUND_DROPS: int = 256
const PICKUP_RADIUS: float = 14.0
const SCATTER_RADIUS: float = 18.0
const CURRENCY_FLIGHT_TIME: float = 0.35

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

func _on_enemy_hit(enemy: Enemy, _amount: float, killed: bool) -> void:
	if not killed:
		return
	var level: int = int(_level_provider.call())
	for value: Variant in _roller.roll_drops(enemy.definition, level, _stash.gems):
		var angle: float = rng.randf_range(0.0, TAU)
		var radius: float = sqrt(rng.randf()) * SCATTER_RADIUS
		spawn_drop(value, enemy.global_position + Vector2(cos(angle), sin(angle) * 0.5) * radius)

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
