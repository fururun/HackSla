class_name ChainTracker
extends RefCounted
## スキルチェインの判定（企画書「スキルチェイン」の決まりごと）
## - 受付時間は無制限。直前に使った1スキルだけを見る
## - 2段階まで：チェイン技が出たら、数え直し（チェイン技は次の起点にならない）
## - 特定スキル同士の指定が、タグ指定より優先
## - 一度出たチェインは discovered に記録（チェイン図鑑用）

signal chain_triggered(rule: ChainRule, first_time: bool)

var last_skill: SkillDef = null
var discovered: Dictionary = {}  ## rule.id -> true


## スキルを使うときに呼ぶ。実際に出す技を返す（チェインが起きれば変化後の技）。
func on_cast(skill: SkillDef, rules: Array[ChainRule], skill_table: Dictionary) -> SkillDef:
	var rule := find_rule(last_skill, skill, rules)
	if rule != null and skill_table.has(rule.result):
		last_skill = null  # 2段階まで
		var first := not discovered.has(rule.id)
		discovered[rule.id] = true
		chain_triggered.emit(rule, first)
		return skill_table[rule.result]
	last_skill = skill
	return skill


## 今の状態で、次にこのスキルを使ったらチェインになるか（発見済みのものだけ光らせる用）
func preview(next: SkillDef, rules: Array[ChainRule], only_discovered: bool = true) -> ChainRule:
	var rule := find_rule(last_skill, next, rules)
	if rule == null:
		return null
	if only_discovered and not discovered.has(rule.id):
		return null
	return rule


static func find_rule(prev: SkillDef, next: SkillDef, rules: Array[ChainRule]) -> ChainRule:
	if prev == null or next == null or prev.chain_only or next.chain_only:
		return null
	var best: ChainRule = null
	for r: ChainRule in rules:
		if not r.matches(prev, next):
			continue
		if best == null or _score(r) > _score(best):
			best = r
	return best


static func _score(r: ChainRule) -> int:
	# 特定スキル指定を最優先。タグ指定どうしなら条件が細かいほうを優先
	return 100 if r.is_specific else r.prev_tags.size() + r.next_tags.size()


func reset() -> void:
	last_skill = null
