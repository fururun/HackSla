class_name EnemyManager
extends Node2D
## 地面座標（画面の縦を2倍）で空間ハッシュを構築する。
## 押し合いの各反復では位置を固定して比較し、補正を最後にまとめて適用する。

const SEPARATION_PASSES: int = 4

var _active: Array[Enemy] = []
var _pool: Array[Enemy] = []
var _grid: Dictionary[Vector2i, Array] = {}
var _corrections: PackedVector2Array = PackedVector2Array()
var _cell_size: float = 12.0
var last_pair_checks: int = 0


func spawn(def: EnemyDef, pos: Vector2) -> Enemy:
	assert(def != null, "敵の定義が必要です")
	var enemy: Enemy = _pool.pop_back() if not _pool.is_empty() else Enemy.new()
	if enemy.get_parent() == null:
		add_child(enemy)
	enemy.manager = self
	enemy.definition = def
	enemy.life = def.life
	enemy.global_position = pos
	enemy.active = true
	enemy.show()
	enemy.add_to_group("enemies")
	enemy.queue_redraw()
	_active.append(enemy)
	return enemy


func despawn(enemy: Enemy) -> void:
	if enemy.manager != self or not enemy.active:
		return
	_active.erase(enemy)
	enemy.active = false
	enemy.hide()
	enemy.remove_from_group("enemies")
	_pool.append(enemy)


func active_count() -> int:
	return _active.size()


func pooled_count() -> int:
	return _pool.size()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		for enemy: Enemy in _active:
			var distance: float = Iso.ground_distance(enemy.global_position, player.global_position)
			if distance > enemy.hit_radius:
				var step: float = minf(enemy.definition.speed * delta, distance - enemy.hit_radius)
				enemy.global_position += (player.global_position - enemy.global_position) * (step / distance)
	last_pair_checks = 0
	_cell_size = 1.0
	for enemy: Enemy in _active:
		_cell_size = maxf(_cell_size, enemy.hit_radius * 2.0)
	for pass_index: int in SEPARATION_PASSES:
		_separate()


func _ground(pos: Vector2) -> Vector2:
	return Vector2(pos.x, pos.y * 2.0)


func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / _cell_size), floori(pos.y * 2.0 / _cell_size))


func _separate() -> void:
	_grid.clear()
	_corrections.resize(_active.size())
	_corrections.fill(Vector2.ZERO)
	for i: int in _active.size():
		var key: Vector2i = _cell(_active[i].global_position)
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append(i)
	for i: int in _active.size():
		var a: Enemy = _active[i]
		var key: Vector2i = _cell(a.global_position)
		for y: int in range(-1, 2):
			for x: int in range(-1, 2):
				var bucket: Array = _grid.get(key + Vector2i(x, y), [])
				for j: int in bucket:
					if j <= i:
						continue
					last_pair_checks += 1
					var b: Enemy = _active[j]
					var distance: float = Iso.ground_distance(a.global_position, b.global_position)
					var diameter: float = a.hit_radius + b.hit_radius
					if distance >= diameter:
						continue
					var direction: Vector2 = _ground(b.global_position - a.global_position) / distance if distance > 0.0001 else Vector2.RIGHT.rotated(float(i + j) * 2.399963)
					var push: Vector2 = direction * ((diameter - distance) * 0.5)
					push.y *= 0.5
					_corrections[i] -= push
					_corrections[j] += push
	for i: int in _active.size():
		_active[i].global_position += _corrections[i]
