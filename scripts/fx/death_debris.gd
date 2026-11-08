class_name DeathDebris
extends Node2D
## 一つの描画ノードで固定長のスロットを再利用する。満杯なら古い演出を置換。

const CAPACITY: int = 32
const DURATION: float = 0.3
const SPREAD: float = 13.0
const RISE: float = 7.0
const INK := Color("#dce0e6")
const DIRECTIONS: Array[Vector2] = [Vector2(-1, -0.3), Vector2(-0.5, -0.8), Vector2(0.3, -1), Vector2(1, -0.2), Vector2(0.6, 0.6), Vector2(-0.4, 0.5)]
const POOL_NAME := "_death_debris"

var _remaining := PackedFloat32Array()
var _origins := PackedVector2Array()
var _cursor: int = 0


func _init() -> void:
	_remaining.resize(CAPACITY)
	_remaining.fill(0.0)
	_origins.resize(CAPACITY)
	set_process(false)
	z_index = 1
	top_level = true


static func spawn(parent: Node, origin: Vector2) -> void:
	var pool := parent.get_node_or_null(NodePath(POOL_NAME)) as DeathDebris
	if pool == null:
		pool = DeathDebris.new()
		pool.name = POOL_NAME
		parent.add_child(pool, false, Node.INTERNAL_MODE_BACK)
	pool.emit_at(origin)


func emit_at(origin: Vector2) -> int:
	var slot: int = _cursor
	for offset: int in CAPACITY:
		var candidate: int = (_cursor + offset) % CAPACITY
		if _remaining[candidate] <= 0.0:
			slot = candidate
			break
	_origins[slot] = origin.round()
	_remaining[slot] = DURATION
	_cursor = (slot + 1) % CAPACITY
	set_process(true)
	queue_redraw()
	return slot


func active_count() -> int:
	var count: int = 0
	for remaining: float in _remaining:
		if remaining > 0.0:
			count += 1
	return count


func tick(delta: float) -> void:
	for i: int in CAPACITY:
		_remaining[i] = maxf(0.0, _remaining[i] - delta)
	set_process(active_count() > 0)
	queue_redraw()


func _process(delta: float) -> void:
	tick(delta)


func _draw() -> void:
	for i: int in CAPACITY:
		if _remaining[i] <= 0.0:
			continue
		var progress: float = 1.0 - _remaining[i] / DURATION
		var ink: Color = INK
		ink.a = 1.0 - progress
		for direction: Vector2 in DIRECTIONS:
			var point: Vector2 = _origins[i] + direction * SPREAD * progress + Vector2(0, -RISE * progress)
			draw_rect(Rect2(point.round(), Vector2(2, 2)), ink)
