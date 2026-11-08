class_name TreeNodeDef
extends RefCounted
## スキルツリーのノード1つ分の定義（data/skill_tree/skill_tree.json の1件）。

const KINDS: PackedStringArray = ["small", "notable", "keystone"]
## ツリーだけが使うステータスのキー（装備の付与効果の STATS に加えて使える）
const EXTRA_STATS: PackedStringArray = [
	"melee_damage_pct", "projectile_damage_pct", "area_damage_pct",  ## スキルの kind ごとのダメージ%
	"supported_damage_pct",  ## 補助ジェムをつけたスキルのダメージ%
	"chain_damage_pct",  ## チェイン技（追加ダメージも）のダメージ%
	"mana_cost_pct",  ## スキルのマナ消費%（マイナスで安くなる）
]

var id: String = ""
var name: String = ""
var kind: String = "small"
var cost: int = 1
var pos: Vector2i = Vector2i.ZERO  ## 画面に並べる格子の位置（根源が 0,0）
var links: PackedStringArray = []
var effects: Dictionary = {}  ## ステータスのキー -> 足す値
var description: String = ""
var start: bool = false  ## true なら、最初から取ってあり、ここからつながるノードを取っていく


static func from_dict(d: Dictionary, errors: Array[String]) -> TreeNodeDef:
	var n := TreeNodeDef.new()
	n.id = str(d.get("id", ""))
	n.name = str(d.get("name", n.id))
	n.kind = str(d.get("kind", "small"))
	n.cost = int(d.get("cost", 1))
	var p: Array = d.get("pos", [0, 0])
	if p.size() == 2:
		n.pos = Vector2i(int(p[0]), int(p[1]))
	n.links = PackedStringArray(d.get("links", []))
	n.effects = d.get("effects", {})
	n.description = str(d.get("description", ""))
	n.start = bool(d.get("start", false))
	if n.id.is_empty():
		errors.append("tree node: id がありません")
	if not KINDS.has(n.kind):
		errors.append("tree node %s: kind「%s」は small / notable / keystone のどれかにしてください" % [n.id, n.kind])
	if n.cost < 0 or (n.cost == 0 and not n.start):
		errors.append("tree node %s: cost は 1 以上にしてください（start のノードだけ 0）" % n.id)
	for key: String in n.effects:
		if not AffixDef.STATS.has(key) and not EXTRA_STATS.has(key):
			errors.append("tree node %s: effects の「%s」は使えないキーです（docs/data_schema.md 参照）" % [n.id, key])
		elif typeof(n.effects[key]) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("tree node %s: effects.%s は数値にしてください" % [n.id, key])
	return n
