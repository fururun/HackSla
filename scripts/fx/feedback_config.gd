class_name FeedbackConfig
extends RefCounted
## 演出だけの調整値。ゲームのダメージ・敵の数値とは独立。

const NUMBER_LIMIT: int = 64
const NUMBER_LIFE: float = 0.6
const NUMBER_RISE: float = 20.0
const NUMBER_JITTER: float = 6.0
const NUMBER_SIZE: Vector2 = Vector2(48, 20)
const NUMBER_OFFSET: Vector2 = Vector2(0, -26)
const FONT_SIZE: int = 14  ## 画面を半分に引いて見るので、世界の中の文字は大きめにする
const OUTLINE_SIZE: int = 2
const NUMBER_Z: int = 20
const FADE_FACTOR: float = 1.5
const HITSTOP_SECONDS: float = 0.045
const HITSTOP_MAX_SECONDS: float = 0.06
const HITSTOP_SCALE: float = 0.05
const HITSTOP_RECOVERY_SECONDS: float = 0.12
const LARGE_DAMAGE: float = 20.0
const SHAKE_SECONDS: float = 0.14
const SHAKE_KILL: float = 1.5  ## 重い敵（岩殻・ボス）を倒したときの揺れ（ドット）
const SHAKE_HIT: float = 0.8  ## 重い一撃のときの揺れ（ドット）
const SHAKE_DAMAGE: float = 70.0  ## この以上のダメージを1体に与えたときだけ揺れる（雑魚への通常攻撃では揺れない）
const COUNTER_SIZE: Vector2 = Vector2(90, 18)
const COUNTER_MARGIN: Vector2 = Vector2(6, 4)
const COUNTER_FONT_SIZE: int = 10
const COUNTER_PULSE_SECONDS: float = 0.18
const COUNTER_PULSE_SCALE: float = 1.25
