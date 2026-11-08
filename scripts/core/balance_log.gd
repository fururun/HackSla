class_name BalanceLog
extends Node
## バランス調整用の記録。1回のプレイ（スタートから、やり直し・やられた・終了まで）ごとに、1行のJSONを書き足す。
## 記録するもの：使ったスキル（回数・チェイン・ダメージ）、最終装備、ドロップしたもの、最大DPS、ボスの討伐の速さ ほか。
## 保存先：
##   プロジェクトの balance_logs/runs.jsonl（残して、あとで集計する。集計は tools/balance/summarize_runs.py）
##   user://logs/balance_runs.jsonl（同じもの。プロジェクトの場所に書けないとき用）
## テスト・撮影（--script）のときは、プロジェクトには書かず、user://logs_tools/ に書く。
## 項目の意味は docs/balance_log.md。

const SCHEMA: int = 1
const FILE_NAME: String = "balance_runs.jsonl"
const PROJECT_DIR: String = "res://balance_logs"
const PROJECT_FILE: String = "runs.jsonl"
const BOSS_POLL_SECONDS: float = 0.25
const MIN_RUN_SECONDS: float = 5.0  ## これより短いプレイ（すぐ閉じた・テスト）は、終了時の自動記録をしない
const MAX_DROP_NAMES: int = 300
const RECENT_HITS: int = 8

var autopilot: Autopilot
var dps_meter: DpsMeter
var start_skill_ids: Array[String] = []

var _manager: EnemyManager
var _player: Player
var _stash: Stash
var _time: float = 0.0  ## このプレイの、ゲームの中の経過秒（止まっている間は進まない）
var _written: bool = false
var _poll_left: float = 0.0
var _start_loadout: Array[Dictionary] = []
var _skills: Dictionary = {}  ## スキルid -> {casts, chained_casts, damage}
var _kills_by_enemy: Dictionary = {}
var _damage_dealt: float = 0.0
var _damage_taken: float = 0.0
var _heals_used: int = 0
var _heal_events: Array[Dictionary] = []  ## 回復を使った時刻・使う前の体力・回復した量
var _boss_wake: float = -1.0
var _boss_rage: float = -1.0
var _boss_kill: float = -1.0
var _boss_life: float = 0.0
var _chain_casts: int = 0
var _equips: int = 0
var _skipped: int = 0
var _picked_gems: Dictionary = {}
var _drop_counts: Dictionary = {"item": 0, "skill_gem": 0, "support_gem": 0, "currency_piles": 0}
var _drop_currency: int = 0
var _drop_items_by_rarity: Dictionary = {}
var _drop_gems: Dictionary = {}
var _drop_names: Array[String] = []
var _dodges: int = 0
var _mana_spent: float = 0.0
var _mana_denied: Dictionary = {}  ## スキルid -> マナ不足で出せなかった回数（0.3秒以内の連続は、1回と数える）
var _mana_denied_at: Dictionary = {}
var _last_mana: float = -1.0
var _damage_taken_by: Dictionary = {}  ## "敵のid:攻撃の種類" -> 受けたダメージの合計
var _recent_hits: Array[Dictionary] = []  ## 直近に受けた攻撃（死因を調べるため。最大 RECENT_HITS 件）
var last_record: Dictionary = {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func setup(manager: EnemyManager, player: Player, stash: Stash, director: LootDirector, pilot: Autopilot, meter: DpsMeter, start_ids: Array[String]) -> void:
	_manager = manager
	_player = player
	_stash = stash
	autopilot = pilot
	dps_meter = meter
	start_skill_ids = start_ids.duplicate()
	_start_loadout = _loadout_snapshot()
	manager.skill_damage.connect(_on_skill_damage)
	manager.enemy_hit.connect(_on_enemy_hit)
	manager.boss_raged.connect(func(_e: Enemy) -> void: _boss_rage = _time)
	player.caster.cast_done.connect(_on_cast_done)
	player.damaged.connect(_on_player_damaged)
	player.dodged.connect(func() -> void: _dodges += 1)
	player.mana_short.connect(_on_mana_short)
	player.vitals.changed.connect(_on_vitals_changed)
	_last_mana = player.vitals.mana
	player.vitals.healed.connect(_on_healed)
	player.vitals.died.connect(func() -> void: finish("death"))
	stash.equipped.connect(func(_slot: String, _new_item: ItemInstance, _old_item: ItemInstance) -> void: _equips += 1)
	stash.skipped.connect(func(_item: ItemInstance) -> void: _skipped += 1)
	stash.picked_up.connect(_on_picked_up)
	director.dropped.connect(_on_dropped)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_time += delta
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = BOSS_POLL_SECONDS
		_poll_boss()


## ボスが動き出した時刻（待機でなくなった最初の時刻）を調べる
func _poll_boss() -> void:
	if _boss_wake >= 0.0 or not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e != null and e.active and e.definition != null and e.definition.is_boss:
			_boss_life = e.definition.life
			if e.state != Enemy.State.IDLE:
				_boss_wake = _time
			return


func _skill_entry(id: String) -> Dictionary:
	if not _skills.has(id):
		_skills[id] = {"casts": 0, "chained_casts": 0, "damage": 0.0}
	return _skills[id]


func _on_skill_damage(skill: SkillDef, amount: float) -> void:
	_damage_dealt += amount
	if skill != null:
		var entry: Dictionary = _skill_entry(skill.id)
		entry["damage"] = float(entry["damage"]) + amount


func _on_enemy_hit(enemy: Enemy, _amount: float, killed: bool) -> void:
	if not killed or enemy.definition == null:
		return
	_kills_by_enemy[enemy.definition.id] = int(_kills_by_enemy.get(enemy.definition.id, 0)) + 1
	if enemy.definition.is_boss and _boss_kill < 0.0:
		_boss_kill = _time
		if _boss_wake < 0.0:
			_boss_wake = _time


## 受けた攻撃を覚える（敵のid・攻撃の種類・ダメージ・その時の、残りの体力）
func _on_player_damaged(amount: float, source: Node) -> void:
	_damage_taken += amount
	var enemy_id: String = "?"
	var kind: String = ""
	var boss_attack: bool = false
	if source is Enemy and (source as Enemy).definition != null:
		enemy_id = (source as Enemy).definition.id
		kind = (source as Enemy).last_attack_kind
		boss_attack = (source as Enemy).definition.is_boss
	var key: String = "%s:%s" % [enemy_id, kind]
	_damage_taken_by[key] = snappedf(float(_damage_taken_by.get(key, 0.0)) + amount, 0.1)
	_recent_hits.append({"t": snappedf(_time, 0.1), "enemy": enemy_id, "kind": kind, "damage": roundi(amount),
		"life_before": roundi(_player.vitals.life) if _player != null else 0, "boss": boss_attack})
	if _recent_hits.size() > RECENT_HITS:
		_recent_hits.pop_front()


## 回復を使った：時刻・使う前の体力（割合）・回復した量
func _on_healed(amount: float) -> void:
	_heals_used += 1
	var max_life: float = maxf(_player.vitals.max_life(), 1.0) if _player != null else 1.0
	var life_after: float = _player.vitals.life if _player != null else 0.0
	_heal_events.append({"t": snappedf(_time, 0.1), "life_before_ratio": snappedf((life_after - amount) / max_life, 0.01), "amount": roundi(amount)})


## マナ不足で出せなかった（連続して押し続けても、0.3秒に1回と数える）
func _on_mana_short(skill: SkillDef) -> void:
	if skill == null:
		return
	if _time - float(_mana_denied_at.get(skill.id, -10.0)) < 0.3:
		return
	_mana_denied_at[skill.id] = _time
	_mana_denied[skill.id] = int(_mana_denied.get(skill.id, 0)) + 1


## マナが減った分を、使った量として数える（増えるときは、回復なので数えない）
func _on_vitals_changed() -> void:
	if _player == null:
		return
	var mana: float = _player.vitals.mana
	if _last_mana >= 0.0 and mana < _last_mana:
		_mana_spent += _last_mana - mana
	_last_mana = mana


func _on_cast_done(_slot: int, skill: SkillDef, _hits: int, chained: bool) -> void:
	var entry: Dictionary = _skill_entry(skill.id)
	entry["casts"] = int(entry["casts"]) + 1
	if chained:
		entry["chained_casts"] = int(entry["chained_casts"]) + 1
		_chain_casts += 1


func _on_picked_up(value: Variant) -> void:
	if value is GemInstance:
		var key: String = "%s:%s" % ["support" if value.kind == GemInstance.Kind.SUPPORT else "skill", value.id]
		_picked_gems[key] = int(_picked_gems.get(key, 0)) + 1


func _on_dropped(value: Variant) -> void:
	if value is ItemInstance:
		_drop_counts["item"] = int(_drop_counts["item"]) + 1
		var rarity: String = (value as ItemInstance).rarity.id
		_drop_items_by_rarity[rarity] = int(_drop_items_by_rarity.get(rarity, 0)) + 1
		if _drop_names.size() < MAX_DROP_NAMES:
			_drop_names.append("%s|%s|%s" % [rarity, (value as ItemInstance).base.id, JSON.stringify((value as ItemInstance).total_stats())])
	elif value is GemInstance:
		var kind: String = "support" if value.kind == GemInstance.Kind.SUPPORT else "skill"
		_drop_counts[kind + "_gem"] = int(_drop_counts[kind + "_gem"]) + 1
		var key: String = "%s:%s" % [kind, value.id]
		_drop_gems[key] = int(_drop_gems.get(key, 0)) + 1
	elif value is int:
		_drop_counts["currency_piles"] = int(_drop_counts["currency_piles"]) + 1
		_drop_currency += int(value)


## やられたときの状況：誰の・どんな攻撃で、どこで、ボスはどんな状態だったか
func _death_snapshot() -> Dictionary:
	var info: Dictionary = {"seconds": snappedf(_time, 0.1), "last_hits": _recent_hits.duplicate(true)}
	if not _recent_hits.is_empty():
		var last: Dictionary = _recent_hits.back()
		info["killer"] = {"enemy": last["enemy"], "kind": last["kind"], "damage": last["damage"]}
	if _player == null or not is_inside_tree():
		return info
	info["position"] = [roundi(_player.global_position.x), roundi(_player.global_position.y)]
	var near: int = 0
	var boss_info: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or not e.active or e.definition == null:
			continue
		var distance: float = Iso.ground_distance(_player.global_position, e.global_position)
		if distance <= 80.0:
			near += 1
		if e.definition.is_boss:
			boss_info = {"distance": roundi(distance), "awake": e.state != Enemy.State.IDLE, "raged": e.raged,
				"life_ratio": snappedf(e.life / maxf(e.definition.life, 1.0), 0.01)}
	info["enemies_within_80"] = near
	if not boss_info.is_empty():
		info["boss"] = boss_info
	return info


static func _sum_ints(d: Dictionary) -> int:
	var total: int = 0
	for key: Variant in d:
		total += int(d[key])
	return total


func _loadout_snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _player == null:
		return out
	for slot: int in range(1, SkillLoadout.SLOT_COUNT + 1):
		var id: String = _player.caster.loadout.skill_id(slot)
		if not id.is_empty():
			out.append({"slot": slot, "skill": id, "support": _player.caster.loadout.support_id(slot)})
	return out


func _equipment_snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _stash == null:
		return out
	for slot: String in _stash.equipment:
		var item: ItemInstance = _stash.equipment[slot]
		var affixes: Array[Dictionary] = []
		for rolled: Dictionary in item.affixes:
			affixes.append({"id": rolled["id"], "value": rolled["value"]})
		out.append({"slot": slot, "name": item.display_name(), "base": item.base.id, "rarity": item.rarity.id,
			"tier": item.rarity.tier, "power": snappedf(item.power(), 0.01), "stats": item.total_stats(), "affixes": affixes})
	return out


## いまの内容から、記録の1件を作る（書かない）。reason は終わり方
func build_record(reason: String) -> Dictionary:
	var skills: Dictionary = {}
	for id: String in _skills:
		var entry: Dictionary = _skills[id]
		skills[id] = {"casts": int(entry["casts"]), "chained_casts": int(entry["chained_casts"]), "damage": roundi(float(entry["damage"]))}
	var boss: Dictionary = {"seen": _boss_life > 0.0, "life": _boss_life}
	if _boss_wake >= 0.0:
		boss["wake_seconds"] = snappedf(_boss_wake, 0.1)
	if _boss_rage >= 0.0:
		boss["rage_seconds"] = snappedf(_boss_rage, 0.1)
	boss["killed"] = _boss_kill >= 0.0
	if _boss_kill >= 0.0:
		boss["kill_seconds"] = snappedf(_boss_kill, 0.1)  # スタートから、ボスを倒すまで
		boss["fight_seconds"] = snappedf(_boss_kill - maxf(_boss_wake, 0.0), 0.1)  # ボスが動き出してから、倒すまで
	var max_dps: float = dps_meter.peak_dps() if dps_meter != null else 0.0
	var player_stats: Dictionary = {}
	if _player != null:
		player_stats = {"level": _player.vitals.level, "max_life": roundi(_player.vitals.max_life()),
			"heals_left": _player.vitals.heal_charges, "heals_used": _heals_used}
	var equipment_stats: Dictionary = {}
	if _stash != null:
		var block: StatBlock = _stash.equipment_stats()
		for key: String in block._values:
			equipment_stats[key] = snappedf(float(block._values[key]), 0.01)
	var total_kills: int = 0
	for id: String in _kills_by_enemy:
		total_kills += int(_kills_by_enemy[id])
	return {
		"schema": SCHEMA,
		"time": Time.get_datetime_string_from_system(),
		"mode": "auto" if (autopilot != null and autopilot.enabled) else "manual",
		"run_no": Autopilot.runs + 1,
		"end_reason": reason,
		"duration_seconds": snappedf(_time, 0.1),
		"player": player_stats,
		"start_loadout": _start_loadout,
		"final_loadout": _loadout_snapshot(),
		"skills": skills,
		"chain_casts": _chain_casts,
		"damage_dealt": roundi(_damage_dealt),
		"damage_taken": roundi(_damage_taken),
		"damage_taken_by": _damage_taken_by,
		"dodges": _dodges,
		"mana": {"max": roundi(_player.vitals.max_mana()) if _player != null else 0, "regen": snappedf(_player.vitals.mana_regen(), 0.1) if _player != null else 0.0,
			"spent": roundi(_mana_spent), "spent_per_second": snappedf(_mana_spent / maxf(_time, 1.0), 0.1),
			"denied_casts": _mana_denied, "denied_total": _sum_ints(_mana_denied)},
		"heals": {"used": _heals_used, "left": _player.vitals.heal_charges if _player != null else 0, "max": PlayerVitals.MAX_HEAL_CHARGES, "events": _heal_events},
		"death": _death_snapshot() if reason == "death" else {},
		"avg_dps": snappedf(_damage_dealt / maxf(_time, 1.0), 0.1),
		"max_dps": snappedf(max_dps, 0.1),
		"kills": total_kills,
		"kills_by_enemy": _kills_by_enemy,
		"boss": boss,
		"final_equipment": _equipment_snapshot(),
		"equipment_stats": equipment_stats,
		"equips": _equips,
		"skipped_items": _skipped,
		"drops": {"counts": _drop_counts, "currency": _drop_currency, "items_by_rarity": _drop_items_by_rarity, "gems": _drop_gems, "item_list": _drop_names},
		"picked_gems": _picked_gems,
	}


## このプレイの記録を、ファイルに1行書き足す。1回のプレイにつき1回だけ（2回目以降は、何もしない）
func finish(reason: String) -> Dictionary:
	if _written:
		return {}
	_written = true
	last_record = build_record(reason)
	_append(JSON.stringify(last_record))
	return last_record


## やり直し（F5・自動）の直前に呼ぶ。ボスを倒していれば「ボス撃破」、そうでなければ「やり直し」
func finish_for_restart() -> Dictionary:
	return finish("boss_cleared" if _boss_kill >= 0.0 else "restart")


func is_written() -> bool:
	return _written


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _time >= MIN_RUN_SECONDS:
		finish("quit")


func _exit_tree() -> void:
	if not _written and _time >= MIN_RUN_SECONDS:
		finish("exit")


# ---- 書き込み ----

static func is_tool_run() -> bool:
	return OS.get_cmdline_args().has("--script")


func _append(line: String) -> void:
	if is_tool_run():
		_write_line("user://logs_tools/" + FILE_NAME, line)
		return
	_write_line("user://logs/" + FILE_NAME, line)
	_write_line(PROJECT_DIR + "/" + PROJECT_FILE, line)


static func _write_line(path: String, line: String) -> void:
	var dir: String = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()
