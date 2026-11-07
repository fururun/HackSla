---
name: gdscript-style
description: 型付きGDScriptの書き方（このプロジェクトの約束）
---

# 型付きGDScriptの書き方（このプロジェクトの約束）

- 変数と関数に型を付ける：`var hp: float = 10.0`、`func f(x: int) -> void:`
- 新しいクラスは `class_name` を付け、1ファイル1クラス
- 数値の定数は名前付きの `const` にする。コードの途中に数字を直接書かない
- データの数値は `data/` から読む（`DataDB.skill("id")` など）
- ファイル名・ノード名は snake_case。コメントは日本語でよい
- `.tscn` は担当のタスクだけが編集する。できるだけコードでノードを組む
- 当たり判定の対象は `enemies` グループ。敵は `take_hit(amount: float, skill: SkillDef)` を持つ
