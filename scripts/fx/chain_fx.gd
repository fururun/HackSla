class_name ChainFx
extends RefCounted
## チェイン技が出たときの、派手な演出。技そのものの絵（SheetFx）に重ねて、
## pixelfx の絵（爆発・範囲・命中の火花）・画面の閃光・「チェイン！」の文字・強い画面の揺れ・一瞬の停止を出す。
## 見た目だけ（ダメージは変わらない）。

const GOLD := Color(1.0, 0.85, 0.35)
const WHITE_GOLD := Color(1.0, 0.97, 0.8)
const BOOST_SIZE: float = 1.8  ## チェイン技の、技の絵の拡大（SkillCaster が使う）
const SHAKE: float = 4.0  ## 画面の揺れ（ドット）。ふつうの撃破の揺れ（1.5）より、ずっと強い
const SCREEN_FLASH_ALPHA: float = 0.32  ## 画面全体の閃光の濃さ


## parent：エフェクトを置く先（World）。origin：使った人の足元。target：当たる場所（敵の位置か、狙った先）。
## caster：pixelfx の絵（爆発・範囲・命中の火花）を重ねるのに使う
static func play(parent: Node, skill: SkillDef, origin: Vector2, target: Vector2, manager: EnemyManager = null, caster: SkillCaster = null) -> void:
	if parent == null or skill == null:
		return
	var element: Color = CombatConsts.ELEMENT_COLORS.get(skill.element, GOLD)
	ScreenFlash.spawn(parent, element.lerp(WHITE_GOLD, 0.6), SCREEN_FLASH_ALPHA)
	if caster != null:
		caster.play_chain_fx(skill, origin, target)
	# 文字（大きめ）
	var text: FloatText = FloatText.spawn(parent, origin + Vector2(0, -38), "チェイン！ %s" % skill.name, GOLD)
	text.add_theme_font_size_override("font_size", 18)
	if manager != null:
		manager.shake(SHAKE)
		manager.hitstop()
