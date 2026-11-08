class_name EnemyManager
extends Node2D
## 地面座標（画面の縦を2倍）で空間ハッシュを構築する。
## 押し合いの各反復では位置を固定して比較し、補正を最後にまとめて適用する。

signal enemy_hit(enemy: Enemy, amount: float, killed: bool)

signal player_hit(damage: float, source: Enemy)
signal aoe_telegraph(enemy: Enemy, radius: float, windup: float)  ## 範囲攻撃の予告が始まった
signal aoe_burst(enemy: Enemy, radius: float)  ## 範囲攻撃が当たった（予告が終わった）
signal boss_raged(enemy: Enemy)  ## ボスが激昂した（体力が半分以下になった）
signal rain_impact(pos: Vector2, radius: float)  ## 岩落としが落ちた（見た目用）
signal charge_telegraph(enemy: Enemy, dir: Vector2, length: float, width: float, windup: float)  ## 突進の予告が始まった
signal charge_started(enemy: Enemy)  ## 突進が始まった
signal charge_ended(enemy: Enemy)  ## 突進が終わった（見た目用）
signal shot_charging(enemy: Enemy, windup: float)  ## 撃つ前のためが始まった
signal shot_fired(enemy: Enemy)  ## 弾を撃った
signal bullet_landed(pos: Vector2, color: Color)  ## 弾が当たった・消えた（見た目用）

const SEPARATION_PASSES: int = 4
const RAIN_STAGGER_SECONDS: float = 0.15  ## 岩落としの円を、1つずつ遅らせて落とす間隔
const AOE_FIRST_DELAY_RATIO: float = 0.35  ## 最初の範囲攻撃までの待ち（aoe_interval に対する割合）

const BULLET_HIT_RADIUS: float = 6.0  ## 弾がプレイヤーに当たる距離（地面）
const CHARGE_MIN_DISTANCE: float = 24.0  ## これより近いと、突進せずに殴る
const RANGED_RETREAT_RATIO: float = 0.55  ## 遠距離の敵は、射程のこの割合より近づかれると、下がる
const RANGED_RETREAT_SPEED: float = 0.8

## 位置が壁などで通れないとき true を返す関数（弾・突進・後退が壁を抜けないように。main が設定する）
var blocked: Callable = Callable()
var _bullets: Array[Dictionary] = []  ## {node, dir(地面の単位の向き), left(残りの距離), damage, speed, source, color}


func _is_blocked(pos: Vector2) -> bool:
	return blocked.is_valid() and bool(blocked.call(pos))


func _ready() -> void:
	aoe_telegraph.connect(_show_aoe_telegraph)
	charge_telegraph.connect(_show_charge_telegraph)


func _show_charge_telegraph(enemy: Enemy, dir: Vector2, length: float, width: float, windup: float) -> void:
	var fx := LineTelegraph.new()
	(enemy_parent if enemy_parent != null else self).add_child(fx)
	fx.play(enemy.global_position, dir, length, width, windup)


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
	enemy.charge_phase = 0
	enemy.charge_timer = def.charge_interval * AOE_FIRST_DELAY_RATIO
	enemy.charge_left = 0.0
	enemy.shot_timer = def.shot_interval * AOE_FIRST_DELAY_RATIO
	enemy.shot_windup_left = 0.0
	enemy.life = def.life
	enemy.global_position = pos
	enemy.reset_physics_interpolation()  # 使い回しの瞬間移動で、前の場所から滑ってこないように
	enemy.ai_enabled = def.behavior == "melee_swarm" or def.behavior == "tank" or def.behavior == "ranged"
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
			rain_impact.emit(spot["pos"], def.rain_radius)
			if Iso.ground_distance(spot["pos"], target) <= def.rain_radius:
				player_hit.emit(def.rain_damage, enemy)
	enemy.rain_timer -= delta
	if enemy.rain_timer <= 0.0:
		enemy.rain_timer = def.rain_interval
		# 動いているプレイヤーに当てるため、予告のあいだに進む先を読む（走り続ければ避けられる、をなくす）
		var player: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
		var velocity: Vector2 = Vector2.ZERO
		if player != null and player.get("velocity") != null:
			velocity = player.get("velocity")
		var predicted: Vector2 = target + velocity * def.rain_windup
		for i: int in def.rain_count:
			# 1つ目は、進む先（読み）。2つ目は、いまの足元（立ち止まった人に）。残りは、進む先のまわり
			var pos: Vector2 = predicted
			if i == 1:
				pos = target
			elif i > 1:
				var angle: float = TAU * float(i) / float(maxi(def.rain_count, 1)) + enemy.rain_timer
				pos = predicted + Vector2(cos(angle), sin(angle) * 0.5) * def.rain_radius * 1.6
			# 順番に時間をずらして落とす（1回の移動では、全部は避けきれない）
			var delay: float = float(i) * RAIN_STAGGER_SECONDS
			enemy.rain_spots.append({"pos": pos, "left": def.rain_windup + delay})
			_show_rain_telegraph(pos, def.rain_radius, def.rain_windup + delay)


func _show_rain_telegraph(pos: Vector2, radius: float, windup: float) -> void:
	var fx := AoeTelegraph.new()
	(enemy_parent if enemy_parent != null else self).add_child(fx)
	fx.play(pos, radius, windup)


## 画面上の位置の差を、地面の単位の向き（y を2倍）にする
func _ground_dir(from: Vector2, to: Vector2) -> Vector2:
	return _ground(to - from).normalized()


## 地面の向きを、画面上の動き（y を半分）にする
func _screen_dir(ground: Vector2) -> Vector2:
	return Vector2(ground.x, ground.y * 0.5)


## 突進：間隔ごとに、細長い赤い帯で予告し、そのあとまっすぐ駆け抜ける。通り道にいたらダメージ（1回の突進で1回）。
## 予告と突進のあいだは、ほかの行動をしない。true を返したら、この敵は突進に専念している
func _update_charge(enemy: Enemy, target: Vector2, delta: float) -> bool:
	var def: EnemyDef = enemy.definition
	if def.charge_damage <= 0.0:
		return false
	var rage_mult: float = def.rage_interval_mult if enemy.raged else 1.0
	match enemy.charge_phase:
		0:
			enemy.charge_timer -= delta
			var distance: float = Iso.ground_distance(enemy.global_position, target)
			if enemy.charge_timer <= 0.0 and distance >= CHARGE_MIN_DISTANCE and distance <= def.charge_length * 1.5:
				enemy.charge_phase = 1
				enemy.charge_left = def.charge_windup
				var ground: Vector2 = _ground_dir(enemy.global_position, target)
				enemy.charge_dir = ground
				charge_telegraph.emit(enemy, _screen_dir(ground), def.charge_length, def.charge_width, def.charge_windup)
				enemy.queue_redraw()
				return true
			return false
		1:
			enemy.charge_left -= delta
			if enemy.charge_left <= 0.0:
				enemy.charge_phase = 2
				enemy.charge_left = def.charge_length / def.charge_speed
				enemy.charge_hit = false
				charge_started.emit(enemy)
				enemy.queue_redraw()
			return true
		_:
			var step: float = def.charge_speed * delta
			var next: Vector2 = enemy.global_position + _screen_dir(enemy.charge_dir) * step
			var stopped: bool = _is_blocked(next)
			if not stopped:
				enemy.global_position = next
			enemy.charge_left -= delta
			if not enemy.charge_hit:
				var reach: float = def.charge_width * 0.5 + enemy.hit_radius * 0.5
				if Iso.ground_distance(enemy.global_position, target) <= reach:
					enemy.charge_hit = true
					player_hit.emit(def.charge_damage, enemy)
			if stopped or enemy.charge_left <= 0.0:
				enemy.charge_phase = 0
				enemy.charge_timer = def.charge_interval * rage_mult
				charge_ended.emit(enemy)
				enemy.queue_redraw()
			return true


## 飛び道具：プレイヤーが shot_range 以内にいたら、ためてから、shot_count 発を扇形に撃つ。ためているあいだは足を止める。
## true を返したら、ためている最中
func _update_shot(enemy: Enemy, target: Vector2, delta: float) -> bool:
	var def: EnemyDef = enemy.definition
	if def.shot_damage <= 0.0:
		return false
	if enemy.shot_windup_left > 0.0:
		enemy.shot_windup_left -= delta
		if enemy.shot_windup_left <= 0.0:
			enemy.shot_windup_left = 0.0
			_fire(enemy, target)
			enemy.shot_timer = def.shot_interval * (def.rage_interval_mult if enemy.raged else 1.0)
		return enemy.shot_windup_left > 0.0
	enemy.shot_timer -= delta
	if enemy.shot_timer <= 0.0 and Iso.ground_distance(enemy.global_position, target) <= def.shot_range:
		if def.shot_windup <= 0.0:
			_fire(enemy, target)
			enemy.shot_timer = def.shot_interval * (def.rage_interval_mult if enemy.raged else 1.0)
			return false
		enemy.shot_windup_left = def.shot_windup
		shot_charging.emit(enemy, def.shot_windup)
		return true
	return false


func _fire(enemy: Enemy, target: Vector2) -> void:
	var def: EnemyDef = enemy.definition
	var base_dir: Vector2 = _ground_dir(enemy.global_position, target)
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	var parent: Node = enemy_parent if enemy_parent != null else self
	for i: int in def.shot_count:
		var offset_deg: float = 0.0 if def.shot_count == 1 else lerpf(-def.shot_spread * 0.5, def.shot_spread * 0.5, float(i) / float(def.shot_count - 1))
		var dir: Vector2 = base_dir.rotated(deg_to_rad(offset_deg))
		var node := EnemyBullet.new()
		var color: Color = def.color.lightened(0.45)
		node.color = color
		node.direction = _screen_dir(dir).normalized()
		parent.add_child(node)
		node.global_position = enemy.global_position
		_bullets.append({"node": node, "dir": dir, "left": def.shot_range * 1.3, "damage": def.shot_damage, "speed": def.shot_speed, "source": enemy, "color": color})
	shot_fired.emit(enemy)


## 弾を進める。プレイヤーに当たる・壁にぶつかる・飛びきったら消える
func _update_bullets(target: Vector2, delta: float) -> void:
	for bullet: Dictionary in _bullets.duplicate():
		var node: EnemyBullet = bullet["node"]
		if not is_instance_valid(node):
			_bullets.erase(bullet)
			continue
		var step: float = float(bullet["speed"]) * delta
		node.global_position += _screen_dir(bullet["dir"]) * step
		bullet["left"] = float(bullet["left"]) - step
		var hit: bool = Iso.ground_distance(node.global_position, target) <= BULLET_HIT_RADIUS
		if hit or bullet["left"] <= 0.0 or _is_blocked(node.global_position):
			if hit and is_instance_valid(bullet["source"]):
				player_hit.emit(bullet["damage"], bullet["source"])
			bullet_landed.emit(node.global_position, bullet["color"])
			_bullets.erase(bullet)
			node.queue_free()


func bullet_count() -> int:
	return _bullets.size()


## 遠距離の敵：射程の中で撃つ。近づかれたら下がり、離れたら近づく。殴らない
func _update_ranged(enemy: Enemy, target: Vector2, delta: float) -> void:
	var def: EnemyDef = enemy.definition
	if _update_shot(enemy, target, delta):
		return  # ためている間は動かない
	var distance: float = Iso.ground_distance(enemy.global_position, target)
	enemy.state = Enemy.State.CHASING
	if distance > def.attack_range:
		var step: float = minf(def.speed * delta, distance - def.attack_range)
		enemy.global_position += (target - enemy.global_position) * (step / distance)
	elif distance < def.attack_range * RANGED_RETREAT_RATIO and distance > 0.001:
		var away: Vector2 = _screen_dir(_ground_dir(target, enemy.global_position))
		var next: Vector2 = enemy.global_position + away * def.speed * RANGED_RETREAT_SPEED * delta
		if not _is_blocked(next):
			enemy.global_position = next


func _update_enemy(enemy: Enemy, target: Vector2, delta: float) -> void:
	if enemy.state == Enemy.State.IDLE or not enemy.ai_enabled:
		return
	var def: EnemyDef = enemy.definition
	_update_rage(enemy)
	_update_rain(enemy, target, delta)
	if def.behavior == "ranged":
		_update_ranged(enemy, target, delta)
		return
	# 攻撃は同時に1つだけ。始まっている攻撃（突進・撃つ前のため・叩きつけの予告）を最後までやってから、次を始める
	if enemy.charge_phase != 0:
		_update_charge(enemy, target, delta)
		return
	if enemy.shot_windup_left > 0.0:
		_update_shot(enemy, target, delta)
		return
	if def.aoe_radius > 0.0:
		_update_aoe(enemy, target, delta)
		if enemy.aoe_windup_left > 0.0:
			return  # 予告のあいだは、動かない・殴らない
	if _update_charge(enemy, target, delta):
		return  # 突進の予告が始まった
	if _update_shot(enemy, target, delta):
		return  # 撃つ前のためが始まった
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
		_update_bullets(player.global_position, delta)
	last_pair_checks = 0
	_cell_size = 1.0
	for enemy: Enemy in _active:
		enemy.can_be_pushed = enemy.ai_enabled and enemy.state != Enemy.State.WINDUP and enemy.charge_phase == 0  # ため中・突進中は押されない（帯からずれない）
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
