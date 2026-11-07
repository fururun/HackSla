class_name Facing
extends RefCounted
## キャラの8方向。ドット絵は5方向（下・右下・右・右上・上）だけ描き、左側は左右反転で作る。
##
## 方向の番号（画面基準、時計回り）:
##   0=右  1=右下  2=下  3=左下  4=左  5=左上  6=上  7=右上

const NAMES: PackedStringArray = ["右", "右下", "下", "左下", "左", "左上", "上", "右上"]

## 描く5方向（スプライトの段の順番）: 0=下 1=右下 2=右 3=右上 4=上
## 8方向 → [描く方向の番号, 左右反転するか]
const SPRITE_TABLE: Array = [
	[2, false],  # 右
	[1, false],  # 右下
	[0, false],  # 下
	[1, true],   # 左下  = 右下を反転
	[2, true],   # 左    = 右を反転
	[3, true],   # 左上  = 右上を反転
	[4, false],  # 上
	[3, false],  # 右上
]


## 画面上の向きベクトル → 8方向の番号
static func dir8(v: Vector2) -> int:
	if v.length_squared() < 0.0001:
		return 2
	var a := fposmod(v.angle(), TAU)  # 右=0、下向きが正（Godotの座標）
	return int(round(a / (TAU / 8.0))) % 8


## 8方向の番号 → 画面上の単位ベクトル
static func to_vector(d: int) -> Vector2:
	return Vector2.RIGHT.rotated(d * TAU / 8.0)


static func sprite_row(d: int) -> int:
	return SPRITE_TABLE[d][0]


static func sprite_flip(d: int) -> bool:
	return SPRITE_TABLE[d][1]
