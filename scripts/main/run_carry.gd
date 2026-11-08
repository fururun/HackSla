class_name RunCarry
extends RefCounted
## リスタートの2種類：
##   RESET（リセット）＝完全にやり直す。レベル・ツリー・装備・ジェムなど、全部最初から。
##   CARRY（引き継いでリスタート）＝やり直すが、成長の一部を持ち越す。
## シーンを作り直す（reload_current_scene）ので、持ち越すものは、ここ（static）に預けて、新しい画面で受け取る。
##
## 引き継ぐもの：レベル・経験値・未使用のポイント・スキルツリーで取ったノード・装備（各部位）・
##   拾ったスキルジェム・補助ジェム・スキル枠の構成（スキルと補助、ランダムにしない）・通貨・回復の残り回数
## 引き継がないもの：マップ・敵・宝箱・地面に落ちているドロップ（マップはまた最初から）
## 数値の理由は docs/balance.md の「リスタート」。

enum Mode { RESET, CARRY }

const MODE_NAMES: Array[String] = ["reset", "carry"]
const KEEP_EQUIPMENT: bool = true  ## 装備を持ち越すか（強すぎるときは false にして、バランスを見る）

static var pending: Dictionary = {}  ## 次の画面が受け取る分（空なら、持ち越しなし）
static var last_mode: Mode = Mode.RESET  ## いまのプレイが、どのリスタートで始まったか
static var carry_depth: int = 0  ## 引き継ぎを続けて何回目か（リセットで 0 に戻る）


static func mode_name(mode: Mode) -> String:
	return MODE_NAMES[mode]


## やり直す前に呼ぶ。RESET なら全部捨てる。CARRY なら、持ち越す分を預かる
static func prepare(mode: Mode, vitals: PlayerVitals, stash: Stash, tree: SkillTree, loadout: SkillLoadout = null) -> void:
	last_mode = mode
	if mode == Mode.RESET or vitals == null:
		pending = {}
		carry_depth = 0
		return
	var equipment: Dictionary = {}
	if KEEP_EQUIPMENT and stash != null:
		for slot: String in stash.equipment:
			equipment[slot] = stash.equipment[slot]
	var gems: Dictionary = {}
	var currency: int = 0
	if stash != null:
		for kind: Variant in stash.gems:
			gems[kind] = (stash.gems[kind] as Dictionary).duplicate()
		currency = stash.currency
	var skills: Array[String] = []
	var supports: Array = []
	if loadout != null:
		for slot: int in range(1, SkillLoadout.SLOT_COUNT + 1):
			skills.append(loadout.skill_id(slot))
			supports.append(loadout.support_ids(slot))
	pending = {
		"level": vitals.level, "xp": vitals.xp, "points": vitals.points,
		"tree": tree.taken_ids() if tree != null else [],
		"equipment": equipment,
		"gems": gems, "currency": currency, "heal_charges": vitals.heal_charges,
		"skills": skills, "supports": supports,
	}
	carry_depth += 1


## 作り直した画面で呼ぶ。預かったものがあれば戻して true。受け取ったら空にする
static func apply(vitals: PlayerVitals, stash: Stash, tree: SkillTree, loadout: SkillLoadout = null) -> bool:
	if pending.is_empty():
		return false
	var data: Dictionary = pending
	pending = {}
	vitals.level = clampi(int(data.get("level", 1)), 1, LevelCurve.MAX_LEVEL)
	vitals.xp = int(data.get("xp", 0))
	vitals.points = int(data.get("points", 0))
	if tree != null:
		tree.load_ids(data.get("tree", []))
	if stash != null:
		var equipment: Dictionary = data.get("equipment", {})
		for slot: String in equipment:
			stash.equipment[slot] = equipment[slot]
		var gems: Dictionary = data.get("gems", {})
		for kind: Variant in gems:
			for id: Variant in gems[kind]:
				stash.add_gem(GemInstance.new(kind, str(id)))
		stash.currency = int(data.get("currency", stash.currency))
		stash.changed.emit()
	if loadout != null:
		var skills: Array = data.get("skills", [])
		var supports: Array = data.get("supports", [])
		for i: int in skills.size():
			var slot: int = i + 1
			if str(skills[i]) != "":
				loadout.set_skill(slot, str(skills[i]))
			else:
				loadout.clear_skill(slot)
			var ids: Array = []
			if i < supports.size():
				ids = supports[i] if supports[i] is Array else [supports[i]]  # 古い形（1つだけ）も読める
			for index: int in SkillLoadout.MAX_SUPPORTS:
				var id: String = str(ids[index]) if index < ids.size() else ""
				loadout.set_support(slot, id, index)
	vitals.heal_charges = clampi(int(data.get("heal_charges", vitals.heal_charges)), 0, PlayerVitals.MAX_HEAL_CHARGES)
	vitals.life = vitals.max_life()
	vitals.mana = vitals.max_mana()
	vitals.changed.emit()
	return true


## 引き継ぎで預かっているスキル構成（空でなければ、スタートでランダムにせず、これを使う）
static func carried_skills() -> Array[String]:
	var result: Array[String] = []
	for id: Variant in pending.get("skills", []):
		if str(id) != "":
			result.append(str(id))
	return result


## テスト・デバッグ用：全部まっさらに戻す
static func clear() -> void:
	pending = {}
	last_mode = Mode.RESET
	carry_depth = 0
