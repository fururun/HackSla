class_name EnemyDef
extends RefCounted
## 敵1種類分の定義（data/enemies/enemies.json の1件）。

const BEHAVIORS: PackedStringArray = ["melee_swarm", "tank", "ranged", "fast", "dummy"]

var id: String = ""
var name: String = ""
var behavior: String = ""
var life: float = 0.0
var speed: float = 0.0
var damage: float = 0.0
var aggro_range: float = 0.0
var windup: float = 0.0
var attack_range: float = 0.0
var attack_interval: float = 0.0
var xp: int = 0
var pack_min: int = 1
var pack_max: int = 1
var color: Color = Color.WHITE
var scale: float = 1.0  ## 絵と当たりの大きさの倍率（ボスは大きい）
var is_boss: bool = false  ## true なら、画面の上にボスの体力の棒を出す


var is_immortal: bool:
	get:
		return life <= 0.0


static func from_dict(d: Dictionary, errors: Array[String]) -> EnemyDef:
	var e := EnemyDef.new()
	e.id = str(d.get("id", ""))
	e.name = str(d.get("name", e.id))
	e.behavior = str(d.get("behavior", ""))
	e.life = float(d.get("life", 0))
	e.speed = float(d.get("speed", 0))
	e.damage = float(d.get("damage", 0))
	e.aggro_range = float(d.get("aggro_range", 0))
	e.windup = float(d.get("windup", 0))
	e.attack_range = float(d.get("attack_range", 0))
	e.attack_interval = float(d.get("attack_interval", 0))
	e.xp = int(d.get("xp", 0))
	var pack: Array = d.get("pack", [1, 1])
	if pack.size() == 2:
		e.pack_min = int(pack[0])
		e.pack_max = int(pack[1])
	e.color = Color.from_string(str(d.get("color", "#ffffff")), Color.WHITE)
	e.scale = float(d.get("scale", 1.0))
	e.is_boss = bool(d.get("boss", false))
	if e.scale <= 0.0:
		errors.append("enemy %s: scale は 0 より大きくしてください" % e.id)
	if e.id.is_empty():
		errors.append("enemy: id がありません")
	if not BEHAVIORS.has(e.behavior):
		errors.append("enemy %s: behavior「%s」は %s のどれかにしてください" % [e.id, e.behavior, ", ".join(BEHAVIORS)])
	if e.life <= 0.0 and e.behavior != "dummy":
		errors.append("enemy %s: life が 0 以下（倒れない敵は behavior を dummy に）" % e.id)
	if e.aggro_range < 0.0 or e.windup < 0.0:
		errors.append("enemy %s: aggro_range / windup は 0 以上にしてください" % e.id)
	if e.pack_min < 1 or e.pack_min > e.pack_max:
		errors.append("enemy %s: pack は 1 以上で、最小を最大以下にしてください" % e.id)
	return e
