---
id: T18
agent: codex
title: 撃破演出（ヒットストップ・ダメージ数字・画面揺れ・撃破数）
allowed: scripts/enemies/enemy.gd scripts/enemies/enemy_manager.gd scripts/fx/ scripts/ui/damage_number.gd tests/test_fx.gd
---

## 目的
群れをまとめて倒す気持ちよさ（企画の芯）を出すための「手応え」の演出を足す。ヒットストップ、ダメージ数字、画面揺れ、撃破数。

## 前提（すでにあるもの）
- `scripts/enemies/enemy.gd`：`take_hit(amount, skill)` が、敵にダメージが入る唯一の入口（スキルも爆発もここを通る）。ライフが0になると `manager.despawn(self)`
- `scripts/enemies/enemy_manager.gd`：敵のプールと管理。`spawn(def, pos)` / `despawn(enemy)`
- `scripts/ui/damage_number.gd`（`DamageNumber`）：浮かんで消えるダメージ数字。いまは毎回 `new` して `queue_free` する（大量に出ると重いので、T18 でプール化する、と書いてある）
- カメラは `Camera2D`（プレイヤーの子）。`get_viewport().get_camera_2d()` で取れる

## やること
1. **信号**：`EnemyManager` に信号 `enemy_hit(enemy: Enemy, amount: float, killed: bool)` を足す。`Enemy.take_hit` から発信する（実際にダメージが入ったときだけ。案山子には出さない）。既存のテスト（`tests/test_enemies.gd`）が通ること
2. **演出の本体**：`scripts/fx/hit_feedback.gd`（`class_name HitFeedback`、`extends Node`）を作り、`EnemyManager` が最初の `spawn` のときに自分の子として1つだけ作る（`main.gd` を触らずに、敵が出れば演出も付くようにするため）。`enemy_hit` を受け取って次を行う
   - **ダメージ数字**：敵の位置に出す。プール化して使い回す（`DamageNumber` を直す）。同時に出る数に上限を設ける（上限を超えたら、一番古いものから再利用する）
   - **ヒットストップ**：撃破したとき、ごく短く時間を止める（`Engine.time_scale` を小さくして、実時間で元に戻す。`create_timer` の `ignore_time_scale` を使う）。連続して撃破されたときは、止めっぱなしにならないよう、停止の合計に上限を設ける。群れを一度に倒したときに、細かい停止が積み重なって固まらない作りにする
   - **画面揺れ**：撃破したときと、大きいダメージのときに、`Camera2D` の `offset` を短く揺らして元に戻す（カメラの元の `offset` を壊さない。カメラが無ければ何もしない）
   - **撃破数**：画面の右上に「撃破 N」を出す（`CanvasLayer` を自分で作る）。増えたときに、少し大きくなって戻る
3. 演出の数値（停止の長さ、上限、揺れの大きさ、数字の上限など）は、`scripts/fx/feedback_config.gd`（`class_name FeedbackConfig`、`const` だけ）にまとめる。コードに直接書かない
4. **テスト**：`tests/test_fx.gd`。ヘッドレスでも動く部分だけ：`enemy_hit` の発信（ダメージ・撃破の区別、案山子では出ない）、ダメージ数字のプール再利用と上限、ヒットストップの合計に上限があること、撃破数の加算

## 仕様（企画書から）
- 演出：ヒットストップ、画面揺れ、撃破数、レアドロップの光の柱と効果音（光の柱と音は今回やらない）
- 画面内の敵は100〜150体が目安。撃破や被弾が1フレームに何十件も起きても重くならない作りにする。エフェクトは使い回し（プール化）が前提

## 完了の条件
- Godot で起動でき、エラーが出ない。`tests/run_tests.gd` が失敗0（既存のテストも通ること）
- `scenes/test/stress.tscn`（T06 の負荷テスト）が、演出が付いた状態でも動く。150体のとき、1フレームの処理が大きく悪化しないこと（結果の数字を報告に書く）
- 見た目が変わるので、撮った画面を最後の報告に添える（`tools/capture/capture.gd` に `--demo=attack` がある。敵を出した画面で撮れなければ、撮れなかったと報告に書く）

## やらないこと
- `scripts/main/main.gd` と `scripts/skills/` `scripts/player/` の変更（Claude があとでつなぐ）
- レアドロップの光の柱・効果音・音（音源が無い）
- 敵の体力バー、敵の被ダメージ時の白い点滅や死亡アニメーション
- ダメージ数字の色分けやクリティカルの表示（ダメージの種類の情報が届いていないので、今回は白一色でよい）
