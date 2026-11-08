---
name: add-data
description: data/ のJSONに数値を足す・直す手順
---

# data/ のJSONに数値を足す・直す手順

1. `docs/data_schema.md` で、使えるキーと型を確かめる
2. `id` は英小文字と `_` だけ。一度決めたら変えない（ほかから参照される）
3. 数値は「仮」でよいが、理由を `docs/balance.md` に書く
4. 新しいキーが必要なら、データの型（`scripts/data/defs/`）の変更が要る。Claude社に頼む
5. 確かめる：`godot --headless --script res://tests/run_tests.gd`（データの間違いは一覧で出る）
