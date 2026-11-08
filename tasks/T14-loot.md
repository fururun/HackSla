---
id: T14
agent: codex
role: impl
title: ドロップの抽選とアイテム生成
allowed: scripts/loot/ tests/test_loot.gd
---

## 目的
敵を倒したときに「何が落ちるか」を決める仕組みを作る。画面に出すのは後のタスク。いまは抽選とアイテムのデータだけ。

## 前提（企画より）
- 大量に倒すと大量に落ちる。通貨と素材は自動で拾い、装備とジェムは地面にこぼれる（表示は後のタスク）
- レアリティは `data/items/rarities.json`（段階・付与効果の数・出やすさ・光の柱）
- 装備の土台は `data/items/bases.json`、付与効果は `data/items/affixes.json`（`AffixDef.can_roll_on(slot)` で付く部位を判定）
- ジェムはスキルジェム（`DataDB.droppable_skills()`。チェイン専用の技は落とさない）と補助ジェム
- 数値は全部 `data/` から読む。コードに直接書かない

## やること
1. `scripts/loot/item_instance.gd`（class_name ItemInstance）：土台・レアリティ・付与効果（id と振られた値）の組。`total_stats() -> Dictionary`（土台の stats ＋付与効果の合計）、`display_name() -> String`
2. `scripts/loot/gem_instance.gd`（class_name GemInstance）：スキルジェムか補助ジェムかと、その id
3. `scripts/loot/loot_roller.gd`（class_name LootRoller）
   - `RandomNumberGenerator` を受け取る（テストで結果を固定できるように）
   - `roll_rarity() -> RarityDef`：weight に比例して選ぶ
   - `roll_item(level: int) -> ItemInstance`：レベル以下の土台から選び、レアリティの付与効果数だけ、部位に合う付与効果を重複なく選ぶ。値は範囲内で整数に丸める
   - `roll_drops(enemy: EnemyDef, level: int) -> Array`：敵の xp が大きいほど多く落ちる仮のルール（ルールは const にまとめる）。装備・ジェム・通貨（数だけ）を返す
4. `tests/test_loot.gd`：固定した乱数で、付与効果が重複しないこと、部位に合わない付与効果が付かないこと、common は付与効果0、1万回の抽選でレアリティの出る割合が weight に近いこと、チェイン専用の技が落ちないこと

## 完了の条件
- テストが全部成功
- 報告に、1万回抽選したときのレアリティごとの回数を書く

## やらないこと
- 地面に落ちる表示、拾う処理、インベントリ（後のタスク）
- `data/` の変更（数値は T12 の担当）
