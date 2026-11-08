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
var rage_aoe_mult: float = 1.0  ## 激昂中の、範囲攻撃の半径の倍率
var rain_radius: float = 0.0  ## 岩落とし（激昂中に、プレイヤーの足元を狙う）の円の半径。0 なら岩落としなし
var rain_damage: float = 0.0
var rain_interval: float = 0.0
var rain_windup: float = 0.0
var rain_count: int = 1  ## 1回に落とす数
var charge_damage: float = 0.0  ## 突進（予告のあと、まっすぐ駆け抜ける）のダメージ。0 なら突進なし
var charge_interval: float = 0.0  ## 突進の間隔（秒）
var charge_windup: float = 0.0  ## 突進の予告の時間（秒）。細長い赤い帯が出る
var charge_speed: float = 0.0  ## 突進の速さ（地面のドット/秒）
var charge_width: float = 0.0  ## 突進が当たる幅（地面のドット）
var charge_length: float = 0.0  ## 突進で進む距離
var shot_damage: float = 0.0  ## 飛び道具のダメージ。0 なら撃たない
var shot_interval: float = 0.0  ## 飛び道具の間隔（秒）
var shot_windup: float = 0.0  ## 撃つ前のため（秒）。この間は足を止める
var shot_speed: float = 0.0  ## 弾の速さ（地面のドット/秒）
var shot_count: int = 1  ## 1回に撃つ数（2つ以上は扇形に広がる）
var shot_spread: float = 0.0  ## 扇形の、いちばん外どうしの角度（度）
var shot_range: float = 0.0  ## この距離（地面）以内にプレイヤーがいたら撃つ。弾は、この1.3倍まで飛ぶ
var tint: Color = Color.WHITE  ## 岩殻の絵にかける色（色違いのレアモンスター用。白なら、そのまま）
var guaranteed_items: int = 0  ## 倒したとき、必ず落とす装備の数（レアモンスター用）
var guaranteed_min_tier: int = 0  ## その装備の、最低のレアリティの段階
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
	e.rage_aoe_mult = float(d.get("rage_aoe_mult", 1.0))
	e.rain_radius = float(d.get("rain_radius", 0))
	e.rain_damage = float(d.get("rain_damage", 0))
	e.rain_interval = float(d.get("rain_interval", 0))
	e.rain_windup = float(d.get("rain_windup", 0))
	e.rain_count = int(d.get("rain_count", 1))
	if e.rage_below < 0.0 or e.rage_below >= 1.0:
		errors.append("enemy %s: rage_below は 0 以上 1 未満にしてください" % e.id)
	if e.rain_radius > 0.0 and (e.rain_interval <= 0.0 or e.rain_windup <= 0.0 or e.rain_damage <= 0.0 or e.rain_count < 1):
		errors.append("enemy %s: rain_radius があるときは、rain_damage / rain_interval / rain_windup / rain_count も必要です" % e.id)
	e.charge_damage = float(d.get("charge_damage", 0))
	e.charge_interval = float(d.get("charge_interval", 0))
	e.charge_windup = float(d.get("charge_windup", 0))
	e.charge_speed = float(d.get("charge_speed", 0))
	e.charge_width = float(d.get("charge_width", 0))
	e.charge_length = float(d.get("charge_length", 0))
	if e.charge_damage > 0.0 and (e.charge_interval <= 0.0 or e.charge_windup <= 0.0 or e.charge_speed <= 0.0 or e.charge_width <= 0.0 or e.charge_length <= 0.0):
		errors.append("enemy %s: charge_damage があるときは、charge_interval / windup / speed / width / length も 0 より大きくしてください" % e.id)
	e.shot_damage = float(d.get("shot_damage", 0))
	e.shot_interval = float(d.get("shot_interval", 0))
	e.shot_windup = float(d.get("shot_windup", 0))
	e.shot_speed = float(d.get("shot_speed", 0))
	e.shot_count = int(d.get("shot_count", 1))
	e.shot_spread = float(d.get("shot_spread", 0))
	e.shot_range = float(d.get("shot_range", 0))
	if e.shot_damage > 0.0 and (e.shot_interval <= 0.0 or e.shot_speed <= 0.0 or e.shot_range <= 0.0 or e.shot_count < 1):
		errors.append("enemy %s: shot_damage があるときは、shot_interval / speed / range / count も必要です" % e.id)
	e.tint = Color.from_string(str(d.get("tint", "#ffffff")), Color.WHITE)
	e.guaranteed_items = int(d.get("guaranteed_items", 0))
	e.guaranteed_min_tier = int(d.get("guaranteed_min_tier", 0))
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
