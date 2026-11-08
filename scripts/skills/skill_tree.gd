class_name SkillTree
extends RefCounted
## スキルツリーの、いまの取得状況。ノードの定義は DataDB.tree_nodes（data/skill_tree/skill_tree.json）。
## 取れるのは、取ったノード（start のノードは最初から取ってある）とつながるノードだけ。ポイントは PlayerVitals.points を使う。

signal changed

var taken: Dictionary = {}  ## ノードid -> true


func _init() -> void:
	reset()


## 最初の状態（start のノードだけ取ってある）に戻す
func reset() -> void:
	taken.clear()
	for node: TreeNodeDef in DataDB.tree_nodes.values():
		if node.start:
			taken[node.id] = true
	changed.emit()


func is_taken(id: String) -> bool:
	return taken.has(id)


## 取った数（start のノードは数えない）
func taken_count() -> int:
	var count: int = 0
	for id: String in taken:
		var node: TreeNodeDef = DataDB.tree_node(id)
		if node != null and not node.start:
			count += 1
	return count


## 取ったノードのうち、ポイントを使ったもの（start 以外）のid。並びはデータの順
func taken_ids() -> Array[String]:
	var out: Array[String] = []
	for node: TreeNodeDef in DataDB.tree_nodes.values():
		if taken.has(node.id) and not node.start:
			out.append(node.id)
	return out


## 使ったポイントの合計
func spent_points() -> int:
	var total: int = 0
	for id: String in taken:
		var node: TreeNodeDef = DataDB.tree_node(id)
		if node != null:
			total += node.cost
	return total


## 取ったノードとつながっているか（リンクは、どちら向きでもよい）
func is_adjacent(id: String) -> bool:
	var node: TreeNodeDef = DataDB.tree_node(id)
	if node == null:
		return false
	for other: String in node.links:
		if taken.has(other):
			return true
	for other_id: String in taken:
		var other_node: TreeNodeDef = DataDB.tree_node(other_id)
		if other_node != null and other_node.links.has(id):
			return true
	return false


## 取れる状態か（まだ取っていない・つながっている）。ポイントは見ない
func is_available(id: String) -> bool:
	return DataDB.tree_node(id) != null and not taken.has(id) and is_adjacent(id)


func can_take(id: String, points: int) -> bool:
	var node: TreeNodeDef = DataDB.tree_node(id)
	return node != null and is_available(id) and points >= node.cost


## ポイントを払って取る。取れたら true
func take(id: String, vitals: PlayerVitals) -> bool:
	if vitals == null or not can_take(id, vitals.points):
		return false
	vitals.points -= (DataDB.tree_node(id) as TreeNodeDef).cost
	taken[id] = true
	changed.emit()
	vitals.changed.emit()
	return true


## 取ったノードの効果の合計
func stats() -> StatBlock:
	var block := StatBlock.new()
	for id: String in taken:
		var node: TreeNodeDef = DataDB.tree_node(id)
		if node == null:
			continue
		for key: String in node.effects:
			block.add(key, float(node.effects[key]))
	return block


## 自動戦闘用：データの順で、いちばん先の「取れるノード」（大ノードは除く）を、ポイントがあれば取る。取った数を返す。
## 先の1つに足りないときは、飛ばさずに待つ（中ノードに届くまで貯める）
func auto_take(vitals: PlayerVitals) -> int:
	var count: int = 0
	while true:
		var next: TreeNodeDef = null
		for node: TreeNodeDef in DataDB.tree_nodes.values():
			if node.kind != "keystone" and is_available(node.id):
				next = node
				break
		if next == null or vitals.points < next.cost:
			break
		take(next.id, vitals)
		count += 1
	return count


## 取ったノードのidを入れ直す（引き継ぎ用）。存在しないidは無視する
func load_ids(ids: Array) -> void:
	reset()
	for id: Variant in ids:
		if DataDB.tree_node(str(id)) != null:
			taken[str(id)] = true
	changed.emit()
