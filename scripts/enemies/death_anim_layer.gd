class_name DeathAnimLayer
extends Node2D
## 敵が倒れたときの、死ぬ動きの絵（スライムは、はじけて消える。岩殻は、崩れて砂ぼこりになる）を、まとめて描く。
## 敵そのものは、倒した瞬間にプールへ戻る（遊びには関係しない）。ここは、倒れた場所に置く見た目だけ。
## 1つのノードで全部描くので、敵を一度に何十体倒しても、ノードは増えない。床の上・キャラより下に描く。

const FRAME_MS: Dictionary = {"slime_death": 80, "spitter_death": 80, "rockgolem_death": 110}
const FRAMES: Dictionary = {"slime_death": 5, "spitter_death": 5, "rockgolem_death": 6}
const MAX_ACTIVE: int = 96

var _items: Array[Dictionary] = []  ## {pos, name, scale, tint, t（経過の秒）}


func _init() -> void:
	z_index = -5  # 床（-10）の上、キャラ（0）の下


## 倒れた場所 pos に、敵 def の死ぬ動きを置く。絵がない敵は、何もしない
func play(def: EnemyDef, pos: Vector2) -> void:
	var anim_name: String = anim_name_for(def)
	if anim_name.is_empty() or Enemy.anim_texture(anim_name, 0) == null:
		return
	if _items.size() >= MAX_ACTIVE:
		_items.pop_front()
	var tint: Color = Color.WHITE
	if def.is_boss:
		tint = Enemy.BOSS_TINT
	elif def.tint != Color.WHITE:
		tint = Color(def.tint.r * Enemy.TINT_BOOST, def.tint.g * Enemy.TINT_BOOST, def.tint.b * Enemy.TINT_BOOST, 1.0)
	_items.append({"pos": pos, "name": anim_name, "scale": def.scale, "tint": tint, "t": 0.0})
	set_process(true)
	queue_redraw()


static func anim_name_for(def: EnemyDef) -> String:
	match def.behavior:
		"melee_swarm":
			return "slime_death"
		"ranged":
			return "spitter_death"
		"tank":
			return "rockgolem_death"
	return ""


func active_count() -> int:
	return _items.size()


func _process(delta: float) -> void:
	for item: Dictionary in _items:
		item["t"] = float(item["t"]) + delta
	_items = _items.filter(func(item: Dictionary) -> bool:
		var frames: int = int(FRAMES[item["name"]])
		return float(item["t"]) * 1000.0 < float(FRAME_MS[item["name"]]) * float(frames))
	if _items.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	for item: Dictionary in _items:
		var anim_name: String = item["name"]
		var index: int = int(float(item["t"]) * 1000.0 / float(FRAME_MS[anim_name]))
		var tex: Texture2D = Enemy.anim_texture(anim_name, index)
		if tex == null:
			continue
		var s: float = float(item["scale"])
		var foot_offset: float = 1.0 if anim_name != "rockgolem_death" else 0.0  # スライムの足元の影は、y=1 まで
		draw_set_transform(item["pos"], 0.0, Vector2(s, s))
		draw_texture(tex, Vector2(-tex.get_size().x * 0.5, foot_offset - tex.get_size().y), item["tint"])
	draw_set_transform(Vector2.ZERO)
