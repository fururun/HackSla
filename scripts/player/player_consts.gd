class_name PlayerConsts
extends RefCounted
## プレイヤーの体力まわりの数値（仮）

const BASE_MAX_LIFE: float = 100.0  ## 基本の最大ライフ（stats の life が上乗せされる）
const LIFE_REGEN_PER_SEC: float = 1.0  ## 時間による体力の回復（1秒あたり）
const BASE_MAX_MANA: float = 100.0  ## 基本の最大マナ（stats の mana が上乗せされる）
const MANA_REGEN_PER_SEC: float = 22.0  ## マナの自然回復（1秒あたり。stats の mana_regen が上乗せされる）
const HIT_INVULN: float = 0.3  ## ダメージを受けた直後の無敵時間（秒）
