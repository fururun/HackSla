---
id: T17
agent: codex
role: impl
title: デバッグ用の操作（FPS表示・データ再読み込み・案山子の呼び出し）
allowed: scripts/debug/ project.godot
---

## 目的
試遊や調整のときに使う、開発用の表示と操作を作る。

## やること
1. `scripts/debug/debug_overlay.gd`（extends CanvasLayer）を作り、`project.godot` の `[autoload]` に `DebugOverlay` として登録する（`[autoload]` 以外の設定は変えない）
2. 操作は `_unhandled_input` でキーを直接見る（`scripts/core/input_setup.gd` は変更しない。F1 だけは既にある `toggle_debug` を使う）
   - F1：表示のオン／オフ。表示内容は FPS、敵の数（`enemies` グループ）、プレイヤーの位置（`player` グループ）、`DataDB.errors` の件数
   - F2：マウスの位置に案山子（`TrainingDummy`）を1体置く。親はプレイヤーと同じノード
   - F3：`DataDB.reload()` で data/ を読み直し、結果（エラー件数）を2秒表示
3. 表示は小さく（フォント8前後）、画面左上。ゲーム画面の邪魔をしない

## 完了の条件
- テストが全部成功（`godot --headless --script res://tests/run_tests.gd`）
- `godot --headless --quit-after 300` がエラーなく終わる
- 画面を撮って確認：`godot --script res://tools/capture/capture.gd -- --out=shots/T17.png`（撮影時は表示をオンにしておく方法を報告に書く）

## やらないこと
- 敵の群れの呼び出し（敵の仕組みができてから別タスク）
- ゲーム本体のスクリプトの変更
