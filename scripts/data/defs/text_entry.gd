class_name TextEntry
extends RefCounted
## 表示名・説明文1件分（data/text/names.json の entries の1件）。
## candidates に全案を持ち、adopted（案の番号）を変えるだけで表示名が切り替わる。

const CATEGORIES: Array[String] = ["skill", "support", "enemy", "rarity", "affix", "chain"]

var category: String = ""
var id: String = ""
var rank: int = 0                  ## レアリティだけ使う（1〜6、下から順）
var adopted: int = 1               ## 採用中の案の番号（candidates の plan）
var candidates: Array[Dictionary] = []  ## {plan, display_name, reading?, description, flavor?, note?}


static func from_dict(d: Dictionary, errors: Array[String]) -> TextEntry:
	var e := TextEntry.new()
	e.category = str(d.get("category", ""))
	e.id = str(d.get("id", ""))
	e.rank = int(d.get("rank", 0))
	e.adopted = int(d.get("adopted", 1))
	for c: Variant in d.get("candidates", []):
		if typeof(c) == TYPE_DICTIONARY:
			e.candidates.append(c)
	var label := "text %s:%s" % [e.category, e.id]
	if not CATEGORIES.has(e.category):
		errors.append("%s: category「%s」は %s のどれかにしてください" % [label, e.category, str(CATEGORIES)])
	if e.id.is_empty():
		errors.append("%s: id がありません" % label)
	if e.candidates.is_empty():
		errors.append("%s: candidates が空です" % label)
	if e.category == "rarity" and (e.rank < 1 or e.rank > 6):
		errors.append("%s: rank は 1〜6 にしてください" % label)
	for c: Dictionary in e.candidates:
		if str(c.get("display_name", "")).is_empty():
			errors.append("%s: 案%s に display_name がありません" % [label, str(c.get("plan", "?"))])
		if _has_digit(str(c.get("description", ""))):
			errors.append("%s: 案%s の説明文に数字があります（数値は別フィールドで持つ）" % [label, str(c.get("plan", "?"))])
	return e


## 数値（ダメージ量など）が書かれているか。「3方向」のような仕様書どおりの方向数だけは許可する
static func _has_digit(s: String) -> bool:
	var rx := RegEx.new()
	rx.compile("[0-9０-９]+(?!方向)")
	return rx.search(s) != null


## 指定した案（0 なら採用中の案。なければ最初の案）
func current(plan_override: int = 0) -> Dictionary:
	var want: int = plan_override if plan_override > 0 else adopted
	for c: Dictionary in candidates:
		if int(c.get("plan", 0)) == want:
			return c
	return candidates[0] if not candidates.is_empty() else {}


func display_name(plan_override: int = 0) -> String:
	return str(current(plan_override).get("display_name", id))


func reading(plan_override: int = 0) -> String:
	return str(current(plan_override).get("reading", ""))


func description(plan_override: int = 0) -> String:
	return str(current(plan_override).get("description", ""))
