---
id: T08
agent: codex
title: 敵AI（索敵・追跡・攻撃・群れの配置）
allowed: scripts/enemies/ scripts/data/defs/enemy_def.gd data/enemies/ tests/test_enemies.gd docs/data_schema.md
---

## 目的
いまの敵（T06）は「プレイヤーに向かってまっすぐ歩くだけ」。これを、群れとして配置され、プレイヤーが近づくと追いかけて殴ってくる敵にする。

## 前提（すでにあるもの）
- `scripts/enemies/enemy_manager.gd`：プール化と押し合い（T06・検収済み）。`spawn(def, pos)` / `despawn(enemy)`
- `scripts/enemies/enemy.gd`：個体。`take_hit(amount, skill)`、`life`、`hit_radius`、`active`
- `scripts/data/defs/enemy_def.gd`：敵の定義。`behavior`、`speed`、`damage`、`attack_range`、`attack_interval`、`pack_min/pack_max` など
- `data/enemies/enemies.json`：群れ小鬼 `swarmling`（melee_swarm）、岩殻 `brute`（tank）、案山子 `training_dummy`（dummy）
- 斜め視点の距離は必ず `Iso.ground_distance()`（縦を2倍にして測る）

## やること
1. **索敵**：敵は最初は動かない（待機）。プレイヤーが「索敵距離」以内に入ったら追いかけ始める。いったん追いかけたら、同じ群れの仲間も一緒に追いかける（群れの1体が気づいたら群れ全体が動く）
   - 索敵距離は新しいデータ項目 `aggro_range`（ドット）として `EnemyDef` と `data/enemies/enemies.json` に足す。`docs/data_schema.md` の敵の表にも1行足す。数値の初期値は、群れ小鬼 120、岩殻 90、案山子 0（動かない）
2. **追跡**：既存の追いかけ処理を、追いかけ状態のときだけ動かす。`dummy` は一切動かない
3. **攻撃**：`attack_range` 以内に入ったら止まって攻撃する。`attack_interval` 秒ごとに1回、プレイヤーに `damage` を与える
   - プレイヤーの体力はまだ存在しない。`EnemyManager` に信号 `player_hit(damage: float, source: Enemy)` を足して、攻撃のたびに発信するだけにする（`player.gd` は触らない）
   - 最初の1撃は、範囲に入ってから `attack_interval` の半分の時間後（いきなり殴らない）
4. **behavior の違い**
   - `melee_swarm`：上記のとおり
   - `tank`：同じ流れで、攻撃前に0.3秒の「ため」を置く（ため中は動かない）。ため時間は定数ではなく、データ項目 `windup`（秒、省略時 0）として足す。岩殻は 0.3
   - `dummy`：何もしない。ほかの `behavior`（ranged / fast）は今回は何もしなくてよい（待機のまま）
5. **群れの配置**：`EnemyManager.spawn_pack(def: EnemyDef, center: Vector2, rng: RandomNumberGenerator) -> Array[Enemy]` を足す。`def.pack_min`〜`pack_max` の数を、`center` の周りに円状にばらまく（地面座標で半径は群れの数に応じて広げる。重なりすぎない程度でよい）。すべて同じ群れ番号を持つ
6. **テスト**：`tests/test_enemies.gd` に足す。待機→索敵→追跡→攻撃の状態遷移、群れ全体が反応すること、`dummy` が動かないこと、`spawn_pack` の数が範囲内であること

## 仕様（企画書から）
- 敵の出方：時間経過で湧き続けない。マップに群れとして配置し、プレイヤーが倒しに行く
- 敵は物理演算（CharacterBody2D / RigidBody2D）を使わない軽い移動処理と、使い回し（プール化）が前提。画面内100〜150体が目安
- 群れ（群れ小鬼）は「数で押す」敵、岩殻は「硬くて遅い」敵。詰まりを作る敵の入口にあたる

## 完了の条件
- Godot で起動でき、エラーが出ない。`tests/run_tests.gd` が失敗0
- `scenes/test/stress.tscn`（T06 の負荷テスト）がそのまま動く
- 150体のとき、1フレームの処理がT06の計測から大きく悪化しない（状態の判断は安く作る。毎フレームすべての敵が全仲間と比べるような作り方はしない）
- 確認方法を最後の報告に書く：テストの実行コマンドと、画面での見え方（待機→追いかける→止まって攻撃）

## やらないこと
- プレイヤーの体力・死亡・被ダメージの表示（信号を出すだけ）
- ranged / fast の挙動
- 敵の絵の変更、ヒットストップや撃破演出（T18）
- `scripts/player/` と `scripts/skills/` の変更（T10 が触る）
