---
name: write-tests
description: テストの書き方と実行の仕方
---

# テストの書き方と実行の仕方

1. `tests/test_<内容>.gd` を作る（`extends RefCounted`、`var t: Variant` を書く）
2. `test_` で始まる関数を書く。それだけで自動で実行される
3. 確かめ方：`t.check(条件, "説明")`、`t.check_eq(実際, 期待, "説明")`
4. 小数は `is_equal_approx` で比べる
5. 乱数は `RandomNumberGenerator` に seed を入れて結果を固定する
6. 実行：`godot --headless --import` のあと `godot --headless --script res://tests/run_tests.gd`
7. 失敗0を確かめてから納品する
