---
name: capture-screen
description: 画面を撮影して確かめる手順（見た目が変わる作業のとき）
---

# 画面を撮影して確かめる手順（見た目が変わる作業のとき）

1. 変更の前に撮る：`godot --script res://tools/capture/capture.gd -- --out=shots/before.png`
2. 変更の後に撮る：`--out=shots/after.png`
3. 斬撃中を撮る：`--demo=attack`
4. 別の画面を撮る：`--scene=res://scenes/test/stress.tscn`
5. 画面の端、文字の重なり、キャラが隠れていないかを見る
6. `shots/` はコミットしない（確認用）
