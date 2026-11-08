class_name RunCarry
extends RefCounted
## リスタートの2種類：
##   RESET（リセット）＝完全にやり直す。レベル・ツリー・装備・ジェムなど、全部最初から。
##   CARRY（引き継いでリスタート）＝やり直すが、成長の一部を持ち越す。
## シーンを作り直す（reload_current_scene）ので、持ち越すものは、ここ（static）に預けて、新しい画面で受け取る。
##
## 引き継ぐもの：レベル・経験値・未使用のポイント・スキルツリーで取ったノード・装備（各部位）
## 引き継がないもの：スキルジェム・補助ジェム（スタートの構成はまたランダム）、通貨、回復の残り回数、マップ・敵・宝箱・ドロップ
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
static func prepare(mode: Mode, vitals: PlayerVitals, stash: Stash, tree: SkillTree) -> void:
	last_mode = mode
	if mode == Mode.RESET or vitals == null:
		pending = {}
		carry_depth = 0
		return
	var equipment: Dictionary = {}
	if KEEP_EQUIPMENT and stash != null:
		for slot: String in stash.equipment:
			equipment[slot] = stash.equipment[slot]
	pending = {
		"level": vitals.level, "xp": vitals.xp, "points": vitals.points,
		"tree": tree.taken_ids() if tree != null else [],
		"equipment": equipment,
	}
	carry_depth += 1


## 作り直した画面で呼ぶ。預かったものがあれば戻して true。受け取ったら空にする
static func apply(vitals: PlayerVitals, stash: Stash, tree: SkillTree) -> bool:
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
		stash.changed.emit()
	vitals.life = vitals.max_life()
	vitals.mana = vitals.max_mana()
	vitals.changed.emit()
	return true


## テスト・デバッグ用：全部まっさらに戻す
static func clear() -> void:
	pending = {}
	last_mode = Mode.RESET
	carry_depth = 0
