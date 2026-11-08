---
name: write-task
description: 指示書（tasks/*.md）の書き方。Claude社PMが発注するときに使う
---

# 指示書（tasks/*.md）の書き方

1. `tasks/_template.md` をコピーして `tasks/T<番号>-<内容>.md` にする
2. 先頭の欄を埋める
   - `id`：タスク表の番号（例 T08）
   - `agent`：codex / gemini / claude
   - `role`：その会社の役割（`agents/<会社>/` のファイル名。例 impl, test, perf, research, balance）
   - `title`：コミットとPRのタイトルになる
   - `allowed`：変更してよい場所。ほかのタスクと重ならないこと
3. 本文に書くこと
   - 目的（1〜2文）
   - 前提：企画書の該当部分を文章で貼る（AIは企画書のリンクを開けない）
   - やること（番号付き）
   - 完了の条件（テストが通る、など確かめられる形で）
   - やらないこと
4. 依存するタスクがあれば本文に書き、配る順番を `tasks/README.md` に書く
5. 半日以内で終わる大きさにする。大きければ分ける
