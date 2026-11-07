---
id: T08
agent: codex
role: impl
title: 敵の動きとメイン画面への配置、プレイヤーのライフ
allowed: scripts/enemies/ scripts/main/ scripts/player/player_health.gd tests/test_enemy_ai.gd
---

## 目的
テスト用マップに敵の群れが置かれ、近づくと襲ってきて、プレイヤーがダメージを受けるようにする。

## 前提（企画より）
- 敵は時間で湧き続けない。マップに群れとして配置され、プレイヤーが倒しに行く
- 敵は2種類：群れ小鬼（`swarmling`、数で押す）と岩殻（`brute`、硬くて遅い）。数値は `DataDB.enemy(id)`
- 敵の土台は T06 で作った `EnemyManager` と `Enemy`（`scripts/enemies/`）。物理演算は使わない
- マップ `data/maps/test_01.txt` の記号：`s` 群れ小鬼の群れ、`b` 岩殻

## やること
1. `scripts/main/main.gd` で `EnemyManager` を World に置き、マップの `s` と `b` の位置に群れを出す（数は `EnemyDef.pack_min〜pack_max`、群れの中心の周りに散らす）
2. 敵の動き（`behavior` で分ける）
   - 待機：プレイヤーが一定距離（const、例 120 ドット）に入るまで動かない
   - 発見したら近づき、`attack_range` に入ったら `attack_interval` ごとに `damage` を与える
   - `tank` は遅く、1回が重い。`melee_swarm` は数で囲む
3. `scripts/player/player_health.gd`（class_name PlayerHealth, extends Node）を作り、プレイヤーの子として main.gd で付ける
   - 最大ライフ（const、仮に 100）、`take_damage(amount: float)`、0になったら開始位置に戻ってライフ全回復（プロトタイプなので）
   - 画面左上に「ライフ 80/100」と小さく出す
4. 敵が倒れたら `EnemyManager` からシグナル `enemy_killed(def: EnemyDef, pos: Vector2)` を出す（次のタスクでドロップと経験値に使う）
5. `tests/test_enemy_ai.gd`：待機→発見→攻撃の切り替え、プレイヤーのライフが減ること、0で戻ること、倒すとシグナルが出ること

## 完了の条件
- テストが全部成功、メイン画面が5秒エラーなく動く
- 画面を撮って、群れが配置されていることを確かめる（`skills/capture-screen/`）

## やらないこと
- `scripts/player/player.gd` の変更（T10 が担当）
- ドロップ、経験値、スキル（ほかのタスク）
