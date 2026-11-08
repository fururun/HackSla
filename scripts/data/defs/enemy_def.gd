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
var aoe_radius: float = 0.0  ## 範囲攻撃の半径（地面のドット）。0 なら範囲攻撃なし
var aoe_damage: float = 0.0  ## 範囲攻撃のダメージ
var aoe_interval: float = 0.0  ## 範囲攻撃の間隔（秒）
var aoe_windup: float = 0.0  ## 範囲攻撃の予告の時間（秒）。この間に範囲の外へ出れば避けられる
var rage_below: float = 0.0  ## 体力がこの割合以下になると激昂する（0 なら激昂しない。例 0.5＝半分）
var rage_speed_mult: float = 1.0  ## 激昂中の、動く速さの倍率
var rage_interval_mult: float = 1.0  ## 激昂中の、範囲攻撃の間隔の倍率（小さいほど、頻繁に撃つ）
var rain_radius: float = 0.0  ## 岩落とし（激昂中に、プレイヤーの足元を狙う）の円の半径。0 なら岩落としなし
var rain_damage: float = 0.0
var rain_interval: float = 0.0
var rain_windup: float = 0.0
var rain_count: int = 1  ## 1回に落とす数
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
	e.aoe_radius = float(d.get("aoe_radius", 0))
	e.aoe_damage = float(d.get("aoe_damage", 0))
	e.aoe_interval = float(d.get("aoe_interval", 0))
	e.aoe_windup = float(d.get("aoe_windup", 0))
	if e.aoe_radius > 0.0 and (e.aoe_interval <= 0.0 or e.aoe_windup <= 0.0 or e.aoe_damage <= 0.0):
		errors.append("enemy %s: aoe_radius があるときは、aoe_damage / aoe_interval / aoe_windup も 0 より大きくしてください" % e.id)
	e.rage_below = float(d.get("rage_below", 0))
	e.rage_speed_mult = float(d.get("rage_speed_mult", 1.0))
	e.rage_interval_mult = float(d.get("rage_interval_mult", 1.0))
	e.rain_radius = float(d.get("rain_radius", 0))
	e.rain_damage = float(d.get("rain_damage", 0))
	e.rain_interval = float(d.get("rain_interval", 0))
	e.rain_windup = float(d.get("rain_windup", 0))
	e.rain_count = int(d.get("rain_count", 1))
	if e.rage_below < 0.0 or e.rage_below >= 1.0:
		errors.append("enemy %s: rage_below は 0 以上 1 未満にしてください" % e.id)
	if e.rain_radius > 0.0 and (e.rain_interval <= 0.0 or e.rain_windup <= 0.0 or e.rain_damage <= 0.0 or e.rain_count < 1):
		errors.append("enemy %s: rain_radius があるときは、rain_damage / rain_interval / rain_windup / rain_count も必要です" % e.id)
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
