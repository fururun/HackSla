class_name StartLoadout
extends RefCounted
## スタート時のスキル構成（3つ）を、ランダムに決める。必ず、チェインが1つは組める構成にする。
## 対象は、ふつうに拾えるスキル（チェイン技は除く）。決めた3つは、持ち物（Stash）にも入れる。

const COUNT: int = 3
const MAX_TRIES: int = 500

static var last_ids: Array[String] = []  ## 前回（やり直す前）の構成。やり直したときに、同じ構成にならないようにする


## 同じスキルの組み合わせか（順番は問わない）
static func same_set(a: Array[String], b: Array[String]) -> bool:
	if a.size() != b.size():
		return false
	var x: Array[String] = a.duplicate()
	var y: Array[String] = b.duplicate()
	x.sort()
	y.sort()
	return x == y


## 3つのスキルid。DataDB のチェインの決まりで、どれか2つが、この順に使うとチェインになる
static func roll(rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[SkillDef] = DataDB.droppable_skills()
	var fallback: Array[String] = []
	for id: String in SkillLoadout.DEFAULT_SKILL_IDS:
		fallback.append(id)
	if pool.size() < COUNT:
		return fallback
	for attempt: int in MAX_TRIES:
		var picked: Array[SkillDef] = []
		var candidates: Array[SkillDef] = pool.duplicate()
		for i: int in COUNT:
			var index: int = rng.randi_range(0, candidates.size() - 1)
			picked.append(candidates[index])
			candidates.remove_at(index)
		if not chain_pairs(picked).is_empty():
			var ids: Array[String] = []
			for skill: SkillDef in picked:
				ids.append(skill.id)
			if same_set(ids, last_ids):
				continue  # やり直すたびに、前回とは別の構成にする
			last_ids = ids.duplicate()
			return ids
	return fallback


## この構成で組めるチェイン：[{first: SkillDef, second: SkillDef, rule: ChainRule}]。「first を使ってから second を使う」
static func chain_pairs(skills: Array[SkillDef]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for first: SkillDef in skills:
		for second: SkillDef in skills:
			if first == second:
				continue
			var rule: ChainRule = ChainTracker.find_rule(first, second, DataDB.chains)
			if rule != null:
				out.append({"first": first, "second": second, "rule": rule})
	return out


## 画面に出す一言：「スタート構成：A / B / C　チェイン：A→B＝結果」
static func describe(ids: Array[String]) -> String:
	var skills: Array[SkillDef] = []
	var names: Array[String] = []
	for id: String in ids:
		var skill: SkillDef = DataDB.skill(id)
		if skill != null:
			skills.append(skill)
			names.append(skill.name)
	var chains: Array[String] = []
	for pair: Dictionary in chain_pairs(skills):
		var result: SkillDef = DataDB.skill((pair["rule"] as ChainRule).result)
		chains.append("%s→%s＝%s" % [(pair["first"] as SkillDef).name, (pair["second"] as SkillDef).name, result.name if result != null else "?"])
	return "スタート構成：%s　チェイン：%s" % [" / ".join(names), "、".join(chains) if not chains.is_empty() else "なし"]
