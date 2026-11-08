class_name ChainFx
extends RefCounted
## チェイン技が出たときの、派手な演出。技そのものの絵（SheetFx）に重ねて、
## 足元の二重の輪・当たる場所の閃光と火花・「チェイン！」の文字・画面の揺れを出す。見た目だけ（ダメージは変わらない）。

const GOLD := Color(1.0, 0.85, 0.35)
const WHITE_GOLD := Color(1.0, 0.97, 0.8)
const BOOST_SIZE: float = 1.35  ## チェイン技の、技の絵の拡大（SkillCaster が使う）
const SHAKE: float = 2.6  ## 画面の揺れ（ドット）。ふつうの撃破の揺れ（1.5）より強い


## parent：エフェクトを置く先（World）。origin：使った人の足元。target：当たる場所（敵の位置か、狙った先）
static func play(parent: Node, skill: SkillDef, origin: Vector2, target: Vector2, manager: EnemyManager = null) -> void:
	if parent == null or skill == null:
		return
	var element: Color = CombatConsts.ELEMENT_COLORS.get(skill.element, GOLD)
	var reach: float = maxf(skill.radius, 24.0)
	# 足元：属性の色の大きな輪と、金色の輪（少し小さく、少し遅れて）
	EnemyFx.spawn(parent, EnemyFx.Kind.RING, origin, element, reach * 1.5, 0.5)
	EnemyFx.spawn(parent, EnemyFx.Kind.RING, origin, GOLD, reach * 1.0, 0.65)
	# 当たる場所：白い閃光、金と属性色の火花
	EnemyFx.spawn(parent, EnemyFx.Kind.FLASH, target, WHITE_GOLD, 26.0, 0.22)
	EnemyFx.spawn(parent, EnemyFx.Kind.BURST, target, GOLD, 36.0, 0.35)
	EnemyFx.spawn(parent, EnemyFx.Kind.BURST, target, element.lightened(0.3), 28.0, 0.4)
	# 文字
	FloatText.spawn(parent, origin + Vector2(0, -34), "チェイン！ %s" % skill.name, GOLD)
	if manager != null:
		manager.shake(SHAKE)
