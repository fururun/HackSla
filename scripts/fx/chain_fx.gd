class_name ChainFx
extends RefCounted
## チェイン技が出たときの、派手な演出。技そのものの絵（SheetFx）に重ねて、
## 画面の閃光・足元の三重の輪・当たる場所の閃光と火花（金・白・属性色）・「チェイン！」の文字・強い画面の揺れ・一瞬の停止を出す。
## 見た目だけ（ダメージは変わらない）。

const GOLD := Color(1.0, 0.85, 0.35)
const WHITE_GOLD := Color(1.0, 0.97, 0.8)
const BOOST_SIZE: float = 1.8  ## チェイン技の、技の絵の拡大（SkillCaster が使う）
const SHAKE: float = 4.0  ## 画面の揺れ（ドット）。ふつうの撃破の揺れ（1.5）より、ずっと強い
const SCREEN_FLASH_ALPHA: float = 0.32  ## 画面全体の閃光の濃さ


## parent：エフェクトを置く先（World）。origin：使った人の足元。target：当たる場所（敵の位置か、狙った先）
static func play(parent: Node, skill: SkillDef, origin: Vector2, target: Vector2, manager: EnemyManager = null) -> void:
	if parent == null or skill == null:
		return
	var element: Color = CombatConsts.ELEMENT_COLORS.get(skill.element, GOLD)
	var reach: float = maxf(skill.radius, 28.0)
	ScreenFlash.spawn(parent, element.lerp(WHITE_GOLD, 0.6), SCREEN_FLASH_ALPHA)
	# 足元：属性の色の大きな輪・金色の輪・白い輪（外へ、遅れて、順に広がる）
	EnemyFx.spawn(parent, EnemyFx.Kind.RING, origin, element, reach * 2.0, 0.55)
	EnemyFx.spawn(parent, EnemyFx.Kind.RING, origin, GOLD, reach * 1.4, 0.7)
	EnemyFx.spawn(parent, EnemyFx.Kind.RING, origin, WHITE_GOLD, reach * 0.8, 0.85)
	# 当たる場所：大きな閃光、金・白・属性色の火花
	EnemyFx.spawn(parent, EnemyFx.Kind.FLASH, target, WHITE_GOLD, 40.0, 0.28)
	EnemyFx.spawn(parent, EnemyFx.Kind.RING, target, GOLD, reach * 1.2, 0.4)
	EnemyFx.spawn(parent, EnemyFx.Kind.BURST, target, GOLD, 52.0, 0.45)
	EnemyFx.spawn(parent, EnemyFx.Kind.BURST, target, WHITE_GOLD, 40.0, 0.35)
	EnemyFx.spawn(parent, EnemyFx.Kind.BURST, target, element.lightened(0.3), 46.0, 0.5)
	# 足元にも、火花
	EnemyFx.spawn(parent, EnemyFx.Kind.BURST, origin, GOLD, 30.0, 0.4)
	# 文字（大きめ）
	var text: FloatText = FloatText.spawn(parent, origin + Vector2(0, -38), "チェイン！ %s" % skill.name, GOLD)
	text.add_theme_font_size_override("font_size", 18)
	if manager != null:
		manager.shake(SHAKE)
		manager.hitstop()
