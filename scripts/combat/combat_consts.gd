class_name CombatConsts
extends RefCounted
## 戦闘まわりの名前付き定数（数値の調整はここ。スキル・補助ジェムの数値は data/ の JSON が正）。

const MELEE_HALF_ANGLE_DEG: float = 60.0  ## 近接の扇形の半分の角度
const MIN_AIM_DISTANCE: float = 1.0  ## これより近い狙い位置は「向き指定なし」として扱う
const SWING_TIME: float = 0.12  ## 発動後に向きを固定する時間（見た目）

const EXPLOSION_RADIUS: float = 24.0  ## 撃破時爆発の半径（地面上のドット）
const EXPLOSION_FX_LIFE: float = 0.25

const AREA_FX_LIFE: float = 0.3  ## 範囲スキルの円の見た目

const PROJECTILE_SPREAD_DEG: float = 15.0  ## 飛び道具が複数のときの間隔
const PROJECTILE_SUBSTEP: float = 3.0  ## 弾を1回に進める最大距離（すり抜け防止）
const HOP_RANGE: float = 80.0  ## 弾が伝わる先を探す距離
const DEFAULT_ENEMY_RADIUS: float = 6.0  ## 当たり判定の半径が無い的のとき

const ELEMENT_COLORS: Dictionary = {
	"physical": Color("#e8e2d0"),
	"fire": Color("#ff8a3d"),
	"cold": Color("#8fd8ff"),
	"lightning": Color("#ffe85c"),
}
