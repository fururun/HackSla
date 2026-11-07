---
id: T19
agent: claude
title: プレイヤーの体力・死亡・経験値とレベル・HUD
allowed: scripts/player/ scripts/ui/hud.gd tests/test_vitals.gd
---

## 目的
敵はプレイヤーを殴ってくる（T08）が、プレイヤーには体力がまだ無い。体力と死亡、経験値とレベルアップ、それを表示する HUD を作る。「群れの中に突っ込むと危ない」という緊張感と、レベルが上がる実感をつくる。

## 前提（すでにあるもの）
- `scripts/enemies/enemy_manager.gd`：信号 `player_hit(damage: float, source: Enemy)`（敵がプレイヤーを殴るたびに発信）、信号 `enemy_hit(enemy, amount, killed)`。`Enemy.definition.xp` が倒したときの経験値
- `scripts/stats/damage_calc.gd`（`apply_armor` など）、`scripts/stats/stat_block.gd`（`StatBlock.get_value(key)`。`life` `armor` などのキー）、`scripts/stats/level_curve.gd`（`xp_to_next(level)`、`add_xp(state, amount)`。中身を読んで使い方を確認する。最大レベル・1レベルごとのポイント数もここ）
- `scripts/player/player.gd`：プレイヤー。`caster`（`SkillCaster`、`caster.stats` が `StatBlock`）を持つ。移動と、`skill_1`〜`skill_6` での発動
- デバッグ表示は `scripts/debug/debug_overlay.gd`（T17）が左上に出している。HUD は左上と重ならないように置く

## やること
1. `scripts/player/player_vitals.gd`（`class_name PlayerVitals`、`extends RefCounted`）を新設
   - 持つもの：`life`、`max_life`（基本値 + `stats` の `life`）、`level`、`xp`、`points`（スキルツリーのポイント。使い道は今回無い）
   - `take_damage(amount: float) -> float`：`stats` の `armor` で `DamageCalc.apply_armor`（敵の攻撃は物理扱い）→ ライフを減らす。実際に引かれた値を返す。死んでいたら何もしない。ダメージを受けた直後の短い無敵時間（`PlayerConsts.HIT_INVULN`、秒）の間は受けない
   - `grant_xp(amount: int)`：`LevelCurve.add_xp` で経験値を足し、レベルが上がったら信号 `leveled_up(level: int)`。レベルが上がったとき、体力を全回復する
   - 信号 `changed`（体力・経験値が変わった）、`died`
   - `is_dead() -> bool`、`reset()`
2. 数値は `scripts/player/player_consts.gd`（`class_name PlayerConsts`、`const` だけ）にまとめる：基本の最大ライフ（100）、無敵時間（0.3秒）。ほか仮の値が要れば同じ場所に
3. `scripts/player/player.gd` を変更：`vitals`（`PlayerVitals`）を持ち、`vitals.stats` として `caster.stats` を共有する（装備のステータスが体力にも効くように）。`on_player_hit(damage: float, source: Node)` を持つ（外から `EnemyManager.player_hit` につなぐ。つなぐのは Claude があとでやるので、このタスクでは `main.gd` を触らない）。死んだら移動とスキル発動を止め、見た目を倒れた色（仮でよい）にする。`reset` で生き返る必要は無い（やり直しはシーンの再読み込みで行う）
4. `scripts/ui/hud.gd`（`class_name Hud`、`extends CanvasLayer`）を新設。`setup(vitals: PlayerVitals)`。画面の左下に、体力の棒（数値つき）、その下にレベルと経験値の棒。レベルが上がったら「レベルアップ！」を短く出す。死んだら画面の中央に「やられた　F5 でやり直し」を出す。見た目は仮でよい（フォントは 8 前後、既存の画面に合わせる）
5. **テスト**：`tests/test_vitals.gd`。ダメージで体力が減る、防御で軽減される、無敵時間中は減らない、0で死ぬ、死後は何も起きない、経験値でレベルが上がり体力が全回復する、最大レベルで止まる、`max_life` が `stats` の `life` で増える

## 仕様（企画書から）
- 序盤は「低レベル、少数の群れを1体ずつ。位置取りが大事」。群れに囲まれると危ないが、すぐには死なない程度の数値にする（敵の攻撃は `data/enemies/enemies.json` の `damage`。群れ小鬼が数体に殴られても、数秒は持つくらい）
- スキルツリーはプロトタイプに入れない。レベルが上がるごとに1ポイントは数えるだけでよい
- 成長はリセットされない方針だが、セーブはプロトタイプに入れない

## 完了の条件
- Godot で起動でき、エラーが出ない。`tests/run_tests.gd` が失敗0（既存のテストも通ること）
- HUD は、確認用の小さな画面を自分で作って（`scenes/test/` に置いてよい。その場合は最後の報告に書く）`tools/capture/capture.gd` で撮り、画面を最後の報告に添える
- 最後の報告に、`main.gd` でつないでほしいこと（どの信号をどこにつなぐか）を具体的に書く

## やらないこと
- `scripts/main/main.gd` `scripts/enemies/` `scripts/skills/` の変更（つなぎ込みは Claude がやる。`allowed` の外は触らない）
- スキルツリー、セーブ、ポーション、体力の自然回復、復活
- 死亡演出（暗転、スローモーション）。メッセージを出すだけ
