# データの書き方（data/ フォルダ）

スキル・補助ジェム・装備・敵・チェインの数値は、すべて `data/` の JSON に書きます。
コードに数値を直接書かないでください。起動時に `DataDB` が読み込み、間違いがあればエラー一覧を出します。

- 1ファイル＝1種類の一覧（配列）。並び順は自由
- `id` は英小文字と `_` だけ。ほかのデータから参照される名前なので、一度決めたら変えない
- `name` などの表示名は仮。テキストは後で Muse がまとめて作り直す
- 数値は「プロトタイプの仮の値」。調整は Gemini の担当（T12・T23）
- 確認方法：`godot --headless --script res://tests/run_tests.gd`（エラーがあれば一覧が出る）

---

## data/skills/skills.json — スキルジェム

| キー | 型 | 意味 |
| --- | --- | --- |
| id | 文字 | 例 `fire_bolt` |
| name | 文字 | 表示名 |
| element | 文字 | `physical` / `fire` / `cold` / `lightning` |
| kind | 文字 | `melee`（近接）/ `projectile`（飛び道具）/ `area`（範囲）/ `movement`（移動）/ `totem`（設置） |
| damage | [最小, 最大] | 1回あたりのダメージ |
| cooldown | 秒 | 再使用までの時間 |
| range | ドット | 届く距離（近接・移動・飛び道具の射程） |
| radius | ドット | 範囲の半径（範囲スキル・近接の振りの広さ）。不要なら 0 |
| speed | ドット/秒 | 飛び道具の速さ。不要なら 0 |
| chain_only | 真偽 | `true` ならスキルチェインでしか出ない技（ジェムとしては落ちない） |
| description | 文字 | 説明文 |

スキルの「タグ」は `element` と `kind` の2つから自動で決まります（チェインの判定に使う）。

## data/supports/supports.json — 補助ジェム

| キー | 型 | 意味 |
| --- | --- | --- |
| id / name / description | 文字 | |
| kinds | 文字の配列 | 付けられるスキルの種類。空なら全部 |
| modifiers | オブジェクト | 効果。使えるキーは下の表だけ |

| modifiers のキー | 意味 |
| --- | --- |
| damage_mult | ダメージ倍率（0.8 = 80%） |
| area_mult | 範囲の倍率 |
| cooldown_mult | 再使用時間の倍率 |
| projectile_count | 飛び道具の追加数 |
| hop_count | 当たった後、近くの敵へ伝わる回数 |
| explode_on_kill | 倒した敵が爆発する確率（0〜1） |
| explode_damage_ratio | 爆発のダメージ（倒した敵の最大ライフに対する割合） |
| chain_damage_mult | チェイン技のダメージ倍率 |
| chain_area_mult | チェイン技の範囲の倍率 |

## data/chains/chains.json — スキルチェイン

直前に使ったスキル（prev）と、今使ったスキル（next）の組み合わせで、今のスキルが `result` の技に変わります。

| キー | 型 | 意味 |
| --- | --- | --- |
| id / name | 文字 | 例 `shatter` / 砕氷 |
| prev_skill / next_skill | 文字 | 特定のスキル同士の組み合わせ（名前付きの特別なチェイン）。使わないなら空 |
| prev_tags / next_tags | 文字の配列 | タグの組み合わせ（例 `["cold","area"]` → `["melee"]`）。特定スキル指定と同時には使わない |
| result | 文字 | 変化後のスキルの id（skills.json で `chain_only: true` のもの） |
| description | 文字 | 図鑑に出る説明 |

- 受付時間は無制限。間に別のスキルを挟むと無効
- 2段階まで（チェイン技の後は数え直し）
- 特定スキル指定のほうが、タグ指定より優先

## data/enemies/enemies.json — 敵

| キー | 型 | 意味 |
| --- | --- | --- |
| id / name | 文字 | |
| behavior | 文字 | `melee_swarm`（数で押す）/ `tank`（硬い単体）/ `ranged`（遠距離）/ `fast`（速い群れ）/ `dummy`（案山子・倒れない） |
| life | 数 | 最大ライフ（案山子は 0 = 無限） |
| speed | ドット/秒 | 移動速度 |
| damage | 数 | 1回の攻撃のダメージ |
| aggro_range | ドット | 索敵距離（地面座標）。群れの1体が気づくと群れ全体が追跡 |
| windup | 秒 | 攻撃直前のため時間。省略時 0。初撃は attack_interval の半分後（ためを含む）、以後は attack_interval ごと。ため時間が待ち時間を超える場合はためを優先 |
| scale | 倍率 | 絵と当たりの大きさの倍率。省略時 1。ボスは大きくする |
| boss | 真偽 | `true` なら、近づくと画面の上にボスの体力の棒が出る。省略時 `false` |
| aoe_radius | ドット | 範囲攻撃の半径（地面座標）。省略時 0（範囲攻撃なし）。あるときは、aoe_damage / aoe_interval / aoe_windup も必要 |
| aoe_damage | 数 | 範囲攻撃のダメージ（円の中にいたときだけ） |
| aoe_interval | 秒 | 範囲攻撃の間隔。最初の1回は、動き出してからこの 0.35 倍の時間のあと |
| aoe_windup | 秒 | 予告の時間。足元に赤い円が満ちていき、満ちきったときに当たる。そのあいだ本人は足を止める（避ける時間） |
| rage_below | 割合 | 体力がこの割合以下になると激昂する（0.5＝半分）。省略時 0（激昂しない） |
| rage_speed_mult | 倍率 | 激昂中の、動く速さの倍率。省略時 1 |
| rage_interval_mult | 倍率 | 激昂中の、範囲攻撃の間隔の倍率（小さいほど頻繁）。省略時 1 |
| rain_radius | ドット | 岩落とし（激昂中に、プレイヤーの足元を狙う小さな円）の半径。省略時 0（岩落としなし）。あるときは rain_damage / rain_interval / rain_windup / rain_count も必要 |
| rain_damage / rain_interval / rain_windup | 数・秒・秒 | 岩落とし1つのダメージ、間隔、予告の時間 |
| rain_count | 数 | 1回に落とす数（1つ目はプレイヤーの足元、残りはそのまわり） |
| attack_range | ドット | 攻撃が届く距離 |
| attack_interval | 秒 | 攻撃の間隔 |
| xp | 数 | 倒したときの経験値 |
| pack | [最小, 最大] | 1つの群れの数 |
| color | "#rrggbb" | 仮の絵の色（ドット絵が入るまで） |

## data/items/ — 装備

`rarities.json`（レアリティ）

| キー | 意味 |
| --- | --- |
| id / name | 例 `rare` / レア（段階の名前は仮） |
| tier | 0 から始まる段階 |
| affixes | [最小, 最大] 付与効果の数 |
| weight | 出やすさ（大きいほど出る） |
| beam | `true` なら光の柱と専用の音（最上位2段階だけ） |
| color | 文字色 "#rrggbb" |

`bases.json`（装備の土台）：`id` / `name` / `slot`（`weapon` / `armor` / `helmet` / `boots` / `ring` / `amulet`）/ `level`（出始めるレベル）/ `stats`（素の性能。キーは下の表）

`affixes.json`（付与効果）：`id` / `name` / `stat` / `value`（[最小, 最大]）/ `weight` / `slots`（付く部位。空なら全部）

| stat に使えるキー | 意味 |
| --- | --- |
| life | 最大ライフ |
| armor | 防御 |
| damage_pct | ダメージ+% |
| fire_damage_pct / cold_damage_pct / lightning_damage_pct | 属性ダメージ+% |
| cast_speed_pct | スキルの速さ+% |
| move_speed_pct | 移動速度+% |
| area_pct | 範囲+% |
| cooldown_pct | 再使用時間の短縮% |
| fire_res / cold_res / lightning_res | 属性耐性% |
| life_on_kill | 撃破時のライフ回復 |
