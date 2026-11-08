class_name RarityDef
extends RefCounted
## レアリティ1段階分の定義（data/items/rarities.json の1件）。段階の数と名前は仮。

var id: String = ""
var name: String = ""
var tier: int = 0
var affix_min: int = 0
var affix_max: int = 0
var weight: float = 0.0
var beam: bool = false  ## true なら光の柱と専用の音（最上位2段階だけ）
var color: Color = Color.WHITE
var stat_mult: float = 1.0  ## 土台の性能にかける倍率（高いレアリティほど、土台そのものも強い）


static func from_dict(d: Dictionary, errors: Array[String]) -> RarityDef:
	var r := RarityDef.new()
	r.id = str(d.get("id", ""))
	r.name = str(d.get("name", r.id))
	r.tier = int(d.get("tier", 0))
	var a: Array = d.get("affixes", [0, 0])
	if a.size() == 2:
		r.affix_min = int(a[0])
		r.affix_max = int(a[1])
	r.weight = float(d.get("weight", 0))
	r.stat_mult = float(d.get("stat_mult", 1.0))
	r.beam = bool(d.get("beam", false))
	r.color = Color.from_string(str(d.get("color", "#ffffff")), Color.WHITE)
	if r.id.is_empty():
		errors.append("rarity: id がありません")
	if r.affix_min > r.affix_max:
		errors.append("rarity %s: affixes の最小が最大より大きい" % r.id)
	return r
