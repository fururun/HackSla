---
name: cross-review
description: 相互チェックの手順（ほかの会社の成果物を確かめる）
---

# 相互チェックの手順（ほかの会社の成果物を確かめる）

1. ファイルを一切変更しない。git の操作もしない
2. 指示書（`.dispatch_task.md` の後半）の「やること」「完了の条件」を読む
3. テストを自分で実行：`godot --headless --import` → `godot --headless --script res://tests/run_tests.gd`
4. メイン画面：`godot --headless --quit-after 300`
5. 変更されたファイルが `allowed` の中だけか
6. AGENTS.md のルールと `docs/concept.md` の「やらないこと」
7. 作業場所の直下に `.dispatch_review.md` を作る
   - 1行目：「判定: OK」か「判定: NG」だけ
   - 2行目以降：実行したコマンドと結果、問題点（ファイル名・理由・直し方）
