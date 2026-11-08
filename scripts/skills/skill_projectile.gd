class_name SkillProjectile
extends Node2D
## 飛び道具の弾（仮の絵）。SkillCaster がプールして使い回す。
## 地面上の向き（縦を2倍にした座標）で進み、敵に当たったら1体にダメージを与える。hop があれば近くの敵へ伝わる。

var active: bool = false
var skill: SkillDef
var damage: float = 0.0
var ctx: SkillCaster.CastContext

var _caster: SkillCaster
var _dir: Vector2 = Vector2.RIGHT  ## 地面上の単位ベクトル
var _speed: float = 0.0
var _range_left: float = 0.0
var _radius: float = 5.0
var _hops_left: int = 0
var _hit_ids: Array[int] = []
var _color: Color = Color.WHITE
var _art: SheetFx  ## 弾の絵（ループ再生）


func _init() -> void:
	z_index = 5
	hide()
	set_physics_process(false)


func launch(caster: SkillCaster, def: SkillDef, context: SkillCaster.CastContext, pos: Vector2,
		dir_ground: Vector2, dmg: float, radius: float, hops: int) -> void:
	_caster = caster
	skill = def
	ctx = context
	damage = dmg
	_dir = dir_ground.normalized()
	_speed = def.speed
	_range_left = def.range
	_radius = radius
	_hops_left = hops
	_hit_ids.clear()
	_color = CombatConsts.ELEMENT_COLORS.get(def.element, Color.WHITE)
	global_position = pos
	active = true
	show()
	set_physics_process(true)
	_update_art()
	queue_redraw()


func _physics_process(delta: float) -> void:
	advance(delta)


## 時間を進める（テストからも呼べる）。大きな delta でも細かく刻んですり抜けを防ぐ。
func advance(delta: float) -> void:
	var remaining := _speed * delta
	while active and remaining > 0.0:
		var step := minf(remaining, CombatConsts.PROJECTILE_SUBSTEP)
		remaining -= step
		_move(step)


func _move(step_len: float) -> void:
	var step := minf(step_len, _range_left)
	global_position += Vector2(_dir.x, _dir.y * 0.5) * step
	_range_left -= step
	var target := _find_hit()
	if target != null:
		_hit_ids.append(target.get_instance_id())
		_caster.projectile_hit(self, target)
		if _hops_left > 0:
			var next := _nearest_for_hop()
			if next != null:
				var d := next.global_position - global_position
				_dir = Vector2(d.x, d.y * 2.0).normalized()
				_update_art()  # 向きが変わったので絵も回す
				_hops_left -= 1
				_range_left = CombatConsts.HOP_RANGE
				return
		_finish()
	elif _range_left <= 0.0:
		_finish()


func _find_hit() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for n: Node in _caster.enemies():
		var e := n as Node2D
		if e == null or _hit_ids.has(e.get_instance_id()):
			continue
		var d := Iso.ground_distance(global_position, e.global_position)
		if d <= _radius + SkillCaster.enemy_radius(e) and d < best_d:
			best = e
			best_d = d
	return best


func _nearest_for_hop() -> Node2D:
	var best: Node2D = null
	var best_d := CombatConsts.HOP_RANGE
	for n: Node in _caster.enemies():
		var e := n as Node2D
		if e == null or _hit_ids.has(e.get_instance_id()):
			continue
		var d := Iso.ground_distance(global_position, e.global_position)
		if d <= best_d:
			best = e
			best_d = d
	return best


func _finish() -> void:
	if _art != null:
		_art.stop()
	active = false
	hide()
	set_physics_process(false)
	_caster.recycle_projectile(self)


## 弾の絵（スプライトシートのループ）を、進む向きに合わせて回す。足元に影も描く
func _update_art() -> void:
	if _art == null:
		_art = SheetFx.new()
		_art.z_index = 0
		add_child(_art)
	var screen_dir := Vector2(_dir.x, _dir.y * 0.5)
	var mirror := screen_dir.x < 0.0
	var rot := Vector2(-screen_dir.x, screen_dir.y).angle() if mirror else screen_dir.angle()
	_art.play(SheetFx.key_for_skill(skill), Vector2.ZERO, 0.0, rot, mirror)
	_art.position = CombatConsts.PROJECTILE_FX_OFFSET


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 3.0, Color(0, 0, 0, 0.3))
