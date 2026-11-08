---
id: T06
agent: codex
role: perf
title: 敵の大量表示の負荷テスト（150体で60fps）
allowed: scripts/enemies/ scenes/test/ tests/test_enemies.gd
---

## 目的
画面内に敵を100〜150体出しても60fpsを保てる「敵の動かし方の土台」を作り、実際に測る。
この土台の上に、次のタスク（T08 敵AI）で敵ごとの動きを足す。

## 前提（企画より）
- 敵は時間で湧き続けない。マップに「群れ」として配置され、プレイヤーが倒しに行く
- 画面内の敵は100〜150体が目安
- 敵に物理演算（CharacterBody2D / RigidBody2D / Area2D）は使わない。軽い移動処理と使い回し（プール化）で作る
- 斜め見下ろし視点。距離は `Iso.ground_distance()`（縦を2倍にして測る）

## やること
1. `scripts/enemies/enemy_manager.gd`（class_name EnemyManager, extends Node2D）を作る
   - 敵を1つのノードがまとめて動かす。敵1体は軽い `Node2D`（class_name Enemy）
   - `spawn(def: EnemyDef, pos: Vector2) -> Enemy` と `despawn(enemy)`。消した敵は捨てずに使い回す（プール）
   - 敵はプレイヤー（`player` グループ）に向かって進み、敵同士は重ならないように押し合う
   - 押し合いは全員×全員で比べない。マス目に分けて近くだけ比べる（空間ハッシュ）
2. 敵は `enemies` グループに入り、`take_hit(amount: float, skill: SkillDef)` を持つ。ライフが0で消える（プールに戻る）。`hit_radius: float` も持つ
3. 仮の絵は `_draw()` で描く（影の楕円＋ `EnemyDef.color` の体）。案山子（`scripts/enemies/training_dummy.gd`）の描き方を参考に
4. `scenes/test/stress.tscn` を作る：テスト用マップ（`data/maps/test_01.txt`、`IsoMap` を使う。`scripts/main/main.gd` の作り方を参考に）に、群れ小鬼（`DataDB.enemy("swarmling")`）を150体出す。画面左上に FPS と敵の数を表示
5. `tests/test_enemies.gd` を作る：150体出して数フレーム動かし、エラーなく動くこと、`take_hit` でライフ0になった敵がプールに戻ること、プールから再利用されること

## 完了の条件
- テストが全部成功（`godot --headless --script res://tests/run_tests.gd`）
- `godot --headless --quit-after 300 res://scenes/test/stress.tscn` がエラーなく終わる
- 報告に、150体のときの1フレームあたりの処理時間（ミリ秒）を書く。測り方：`Performance.get_monitor(Performance.TIME_PROCESS)` を数秒平均。ヘッドレスで測った値であることも書く

## やらないこと
- 敵の攻撃や種類ごとの動き（T08 でやる）
- `scripts/main/` や `scripts/player/` の変更、`scripts/enemies/training_dummy.gd` の変更
- 敵を時間で湧かせる仕組み
