class_name EnemyManager
extends Node2D
## 地面座標（画面の縦を2倍）で空間ハッシュを構築する。
## 押し合いの各反復では位置を固定して比較し、補正を最後にまとめて適用する。

signal enemy_hit(enemy: Enemy, amount: float, killed: bool)

signal player_hit(damage: float, source: Enemy)
signal aoe_telegraph(enemy: Enemy, radius: float, windup: float)  ## 範囲攻撃の予告が始まった
signal aoe_burst(enemy: Enemy, radius: float)  ## 範囲攻撃が当たった（予告が終わった）
signal boss_raged(enemy: Enemy)  ## ボスが激昂した（体力が半分以下になった）

const SEPARATION_PASSES: int = 4
const AOE_FIRST_DELAY_RATIO: float = 0.35  ## 最初の範囲攻撃までの待ち（aoe_interval に対する割合）

func _ready() -> void:
	aoe_telegraph.connect(_show_aoe_telegraph)


## 範囲攻撃の予告の絵（赤い円が広がる）
func _show_aoe_telegraph(enemy: Enemy, radius: float, windup: float) -> void:
	var fx := AoeTelegraph.new()
	(enemy_parent if enemy_parent != null else self).add_child(fx)
	fx.play(enemy.global_position, radius, windup)


var enemy_parent: Node  ## 敵を置く先。Y軸ソートする親を指定する（空なら自分の子）
var _feedback: HitFeedback

var _packs: Dictionary[int, Array] = {}
var _next_pack_id: int = 0

var _active: Array[Enemy] = []
var _pool: Array[Enemy] = []
var _grid: Dictionary[Vector2i, Array] = {}
var _corrections: PackedVector2Array = PackedVector2Array()
var _cell_size: float = 12.0
var last_pair_checks: int = 0


func spawn(def: EnemyDef, pos: Vector2) -> Enemy:
	assert(def != null, "敵の定義が必要です")
	if _feedback == null:
		_feedback = HitFeedback.new()
		add_child(_feedback, false, Node.INTERNAL_MODE_BACK)
		enemy_hit.connect(_feedback.on_enemy_hit)
	var enemy: Enemy = _pool.pop_back() if not _pool.is_empty() else Enemy.new()
	if enemy.get_parent() == null:
		# Y軸ソートする親（World）の直下に置く。管理ノードの下に置くと、群れ全体が1枚として
		# 壁やプレイヤーと前後を比べられてしまい、描画順がずれる
		(enemy_parent if enemy_parent != null else self).add_child(enemy)
	enemy.manager = self
	enemy.definition = def
	enemy.hit_radius = (Enemy.TANK_HIT_RADIUS if def.behavior == "tank" else Enemy.DEFAULT_HIT_RADIUS) * def.scale
	enemy.aoe_timer = def.aoe_interval * AOE_FIRST_DELAY_RATIO  # 範囲攻撃は、動き出してから少し待ってから
	enemy.aoe_windup_left = 0.0
	enemy.raged = false
	enemy.rain_spots.clear()
	enemy.rain_timer = 0.0
	enemy.life = def.life
	enemy.global_position = pos
	enemy.reset_physics_interpolation()  # 使い回しの瞬間移動で、前の場所から滑ってこないように
	enemy.ai_enabled = def.behavior == "melee_swarm" or def.behavior == "tank"
	enemy.can_be_pushed = enemy.ai_enabled
	enemy.state = Enemy.State.IDLE
	enemy.pack_id = -1
	enemy.attack_timer = 0.0
	enemy.active = true
	enemy.show()
	enemy.add_to_group("enemies")
	enemy.queue_redraw()
	_active.append(enemy)
	return enemy


## 群れを置く。count が 0 以上なら、その数にする（小さな群れ用）。負なら、定義の pack の範囲から選ぶ
func spawn_pack(def: EnemyDef, center: Vector2, rng: RandomNumberGenerator, forced_count: int = -1) -> Array[Enemy]:
	var members: Array[Enemy] = []
	var count: int = forced_count if forced_count >= 0 else rng.randi_range(def.pack_min, def.pack_max)
	var id: int = _next_pack_id
	_next_pack_id += 1
	# 等間隔の円周配置。地面で隣同士の直径を確保し、角度だけを乱数化する。
	var rotation: float = rng.randf_range(0.0, TAU)
	for i: int in count:
		var angle: float = rotation + TAU * float(i) / float(count)
		var enemy: Enemy = spawn(def, center)
		var radius: float = 0.0 if count == 1 else enemy.hit_radius / sin(PI / float(count))
		enemy.global_position += Vector2(cos(angle), sin(angle) * 0.5) * radius
		enemy.pack_id = id
		members.append(enemy)
	_packs[id] = members.duplicate()
	return members


func _alert(enemy: Enemy) -> void:
	if enemy.pack_id < 0:
		enemy.state = Enemy.State.CHASING
		return
	# 待機からの遷移時だけ群れを訪問する。全個体同士の距離比較はしない。
	for member: Enemy in _packs[enemy.pack_id]:
		if member.ai_enabled and member.state == Enemy.State.IDLE:
			member.state = Enemy.State.CHASING


## 範囲攻撃（ボスなど）。一定の間隔で、足元に赤い円で予告し、予告が終わったときに円の中にいたらダメージ。
## 予告のあいだ、本人は足を止める（避ける時間を作る）
func _update_aoe(enemy: Enemy, target: Vector2, delta: float) -> void:
	var def: EnemyDef = enemy.definition
	if enemy.aoe_windup_left > 0.0:
		enemy.aoe_windup_left -= delta
		if enemy.aoe_windup_left <= 0.0:
			enemy.aoe_windup_left = 0.0
			enemy.aoe_timer = def.aoe_interval * (def.rage_interval_mult if enemy.raged else 1.0)
			if Iso.ground_distance(enemy.global_position, target) <= def.aoe_radius:
				player_hit.emit(def.aoe_damage, enemy)
			aoe_burst.emit(enemy, def.aoe_radius)
		return
	enemy.aoe_timer -= delta
	if enemy.aoe_timer <= 0.0:
		enemy.aoe_windup_left = def.aoe_windup
		aoe_telegraph.emit(enemy, def.aoe_radius, def.aoe_windup)


## 激昂（体力が rage_below 以下になったボス）：動きが速くなり、範囲攻撃の間隔が短くなり、
## プレイヤーの足元を狙う「岩落とし」（rain_*）を始める
func _update_rage(enemy: Enemy) -> void:
	var def: EnemyDef = enemy.definition
	if enemy.raged or def.rage_below <= 0.0 or def.life <= 0.0:
		return
	if enemy.life <= def.life * def.rage_below:
		enemy.raged = true
		enemy.rain_timer = def.rain_interval * 0.5  # 激昂してすぐは、少し待ってから
		boss_raged.emit(enemy)
		enemy.queue_redraw()


## 岩落とし：プレイヤーのいまいる場所と、そのまわりに、小さな赤い円を出す。予告のあと、円の中にいたらダメージ。
## 本人は、動きながら撃つ（範囲攻撃と違って、足を止めない）
func _update_rain(enemy: Enemy, target: Vector2, delta: float) -> void:
	var def: EnemyDef = enemy.definition
	if not enemy.raged or def.rain_radius <= 0.0:
		return
	# 予告中の円を進める
	for spot: Dictionary in enemy.rain_spots.duplicate():
		spot["left"] = float(spot["left"]) - delta
		if float(spot["left"]) <= 0.0:
			enemy.rain_spots.erase(spot)
			if Iso.ground_distance(spot["pos"], target) <= def.rain_radius:
				player_hit.emit(def.rain_damage, enemy)
	enemy.rain_timer -= delta
	if enemy.rain_timer <= 0.0:
		enemy.rain_timer = def.rain_interval
		for i: int in def.rain_count:
			# 1つ目は、プレイヤーのいまの足元。残りは、そのまわり
			var pos: Vector2 = target
			if i > 0:
				var angle: float = TAU * float(i) / float(maxi(def.rain_count, 1)) + enemy.rain_timer
				pos = target + Vector2(cos(angle), sin(angle) * 0.5) * def.rain_radius * 1.6
			enemy.rain_spots.append({"pos": pos, "left": def.rain_windup})
			_show_rain_telegraph(pos, def.rain_radius, def.rain_windup)


func _show_rain_telegraph(pos: Vector2, radius: float, windup: float) -> void:
	var fx := AoeTelegraph.new()
	(enemy_parent if enemy_parent != null else self).add_child(fx)
	fx.play(pos, radius, windup)


func _update_enemy(enemy: Enemy, target: Vector2, delta: float) -> void:
	if enemy.state == Enemy.State.IDLE or not enemy.ai_enabled:
		return
	var def: EnemyDef = enemy.definition
	_update_rage(enemy)
	_update_rain(enemy, target, delta)
	if def.aoe_radius > 0.0:
		_update_aoe(enemy, target, delta)
		if enemy.aoe_windup_left > 0.0:
			return  # 予告のあいだは、動かない・殴らない
	var distance: float = Iso.ground_distance(enemy.global_position, target)
	if enemy.state == Enemy.State.WINDUP:
		# ため中は足を止め、振り終わりに射程を再確認する（離れれば回避できる）。
		enemy.attack_timer -= delta
	elif distance > def.attack_range:
		enemy.state = Enemy.State.CHASING
		enemy.attack_timer = 0.0
		var speed: float = def.speed * (def.rage_speed_mult if enemy.raged else 1.0)
		var step: float = minf(speed * delta, distance - def.attack_range)
		enemy.global_position += (target - enemy.global_position) * (step / distance)
		return
	else:
		if enemy.state == Enemy.State.CHASING:
			enemy.state = Enemy.State.ATTACKING
			enemy.attack_timer = maxf(def.attack_interval * 0.5, def.windup)
		enemy.attack_timer -= delta
		if def.windup > 0.0 and enemy.attack_timer <= def.windup + 0.000001:
			enemy.state = Enemy.State.WINDUP
	if enemy.attack_timer > 0.000001:
		return
	if distance <= def.attack_range:
		# 0間隔の不正データでも1フレームに複数回発信しない。
		enemy.state = Enemy.State.ATTACKING
		enemy.attack_timer = maxf(def.attack_interval, def.windup)
		player_hit.emit(def.damage, enemy)
	else:
		enemy.state = Enemy.State.CHASING
		enemy.attack_timer = 0.0


func despawn(enemy: Enemy) -> void:
	if enemy.manager != self or not enemy.active:
		return
	if enemy.pack_id >= 0:
		var members: Array = _packs[enemy.pack_id]
		members.erase(enemy)
		if members.is_empty():
			_packs.erase(enemy.pack_id)
	enemy.pack_id = -1
	enemy.state = Enemy.State.IDLE
	enemy.attack_timer = 0.0
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
			if enemy.state == Enemy.State.IDLE and enemy.ai_enabled and Iso.ground_distance(enemy.global_position, player.global_position) <= enemy.definition.aggro_range:
				_alert(enemy)
		# 信号の受信側が撃破・生成しても走査中の配列を壊さない。
		for enemy: Enemy in _active.duplicate():
			if enemy.active:
				_update_enemy(enemy, player.global_position, delta)
	last_pair_checks = 0
	_cell_size = 1.0
	for enemy: Enemy in _active:
		enemy.can_be_pushed = enemy.ai_enabled and enemy.state != Enemy.State.WINDUP
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
					var move_a: bool = a.can_be_pushed
					var move_b: bool = b.can_be_pushed
					var movers: int = int(move_a) + int(move_b)
					if movers == 0:
						continue
					var push: Vector2 = direction * ((diameter - distance) / float(movers))
					push.y *= 0.5
					if move_a:
						_corrections[i] -= push
					if move_b:
						_corrections[j] += push
	for i: int in _active.size():
		_active[i].global_position += _corrections[i]
