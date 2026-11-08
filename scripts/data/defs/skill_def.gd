class_name SkillDef
extends RefCounted
## スキルジェム1つ分の定義（data/skills/skills.json の1件）。

const ELEMENTS: PackedStringArray = ["physical", "fire", "cold", "lightning"]
const KINDS: PackedStringArray = ["melee", "projectile", "area", "movement", "totem"]

var id: String = ""
var name: String = ""
var element: String = "physical"
var kind: String = "melee"
var damage_min: float = 0.0
var damage_max: float = 0.0
var cooldown: float = 0.0
var mana_cost: float = 0.0  ## 使うときに消費するマナ（チェイン技は、元のスキルの分を払うので 0）
var range: float = 0.0
var radius: float = 0.0
var speed: float = 0.0
var chain_only: bool = false
var description: String = ""


## チェイン判定に使うタグ（属性と種類）
var tags: PackedStringArray:
	get:
		return PackedStringArray([element, kind])


static func from_dict(d: Dictionary, errors: Array[String]) -> SkillDef:
	var s := SkillDef.new()
	s.id = str(d.get("id", ""))
	s.name = str(d.get("name", s.id))
	s.element = str(d.get("element", ""))
	s.kind = str(d.get("kind", ""))
	var dmg: Array = d.get("damage", [0, 0])
	if dmg.size() == 2:
		s.damage_min = float(dmg[0])
		s.damage_max = float(dmg[1])
	else:
		errors.append("skill %s: damage は [最小, 最大] で書いてください" % s.id)
	s.cooldown = float(d.get("cooldown", 0.0))
	s.mana_cost = float(d.get("mana_cost", 0.0))
	if s.mana_cost < 0.0:
		errors.append("skill %s: mana_cost は 0 以上にしてください" % s.id)
	s.range = float(d.get("range", 0.0))
	s.radius = float(d.get("radius", 0.0))
	s.speed = float(d.get("speed", 0.0))
	s.chain_only = bool(d.get("chain_only", false))
	s.description = str(d.get("description", ""))

	if s.id.is_empty():
		errors.append("skill: id がありません")
	if not ELEMENTS.has(s.element):
		errors.append("skill %s: element「%s」は %s のどれかにしてください" % [s.id, s.element, ", ".join(ELEMENTS)])
	if not KINDS.has(s.kind):
		errors.append("skill %s: kind「%s」は %s のどれかにしてください" % [s.id, s.kind, ", ".join(KINDS)])
	if s.damage_min > s.damage_max:
		errors.append("skill %s: damage の最小が最大より大きい" % s.id)
	if s.kind == "projectile" and s.speed <= 0.0:
		errors.append("skill %s: 飛び道具は speed が必要です" % s.id)
	return s


## ダメージの平均（コストあたりの強さの比較に使う）
func average_damage() -> float:
	return (damage_min + damage_max) * 0.5


func roll_damage(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(damage_min, damage_max)
