---
id: T20
agent: codex
title: ドロップを地面に出して拾う（ジェム・装備・通貨）と持ち物
allowed: scripts/loot/ scripts/ui/skill_screen.gd scripts/ui/loot_hud.gd tests/test_loot_drops.gd tests/test_skill_screen.gd
---

## 目的
敵を倒すとドロップが地面にこぼれ、歩いて拾えるようにする。拾ったジェムはスキル装備画面で使え、拾った装備はステータスに効く。「大量に倒すと大量に落ちる」手応えと、「補助ジェムを付け替えて強くなる」流れをつなぐ。

## 前提（すでにあるもの）
- `scripts/loot/loot_roller.gd`（`LootRoller`）：`roll_drops(enemy: EnemyDef, level: int) -> Array`。戻りは `ItemInstance`（装備）・`GemInstance`（ジェム）・`int`（通貨。末尾に1件に集約）の混ざった配列。`xp` が0の敵は何も落とさない
- `scripts/loot/item_instance.gd`（`ItemInstance`：`base`、`rarity`、`affixes`、`total_stats() -> Dictionary`、`display_name()`）、`gem_instance.gd`（`GemInstance`：`kind`（SKILL / SUPPORT）、`id`）
- `scripts/data/defs/rarity_def.gd`：`beam`（光の柱を出す最上位2段階）、`color`、`tier`
- `scripts/enemies/enemy_manager.gd`：信号 `enemy_hit(enemy: Enemy, amount: float, killed: bool)`。`killed` のとき、その敵は倒れている。`enemy.definition`、`enemy.global_position`
- `scripts/ui/skill_screen.gd`（T11）：いまは `_available_skills()` / `_available_supports(slot)` が `DataDB` にあるものを**すべて**出している。持ち物に差し替えられるよう切り出してある
- `scripts/stats/stat_block.gd`（`StatBlock`）、`scripts/skills/skill_caster.gd`（`caster.stats`）
- 位置の前後は、敵・プレイヤーと同じ Y軸ソートの親（`World`）の直下に置いて合わせる（敵が `World` 直下に置かれるのと同じ理由）

## やること
1. **持ち物** `scripts/loot/stash.gd`（`class_name Stash`、`extends RefCounted`）
   - ジェム：スキルジェムと補助ジェムの所持の集合（`has_gem(kind, id)`、`add_gem(gem)`。重複して拾ったものは1つのまま）。**最初から持っているもの**：スキル `slash` `frost_bloom` `fire_bolt`（これまでの初期の枠）と、補助ジェム全部（`DataDB.supports` のもの）。補助ジェムは落ちにくいため、最初から持たせてよい（ジェム全部の名前を `const` の配列で書かず、`DataDB` から取る）
   - 装備：部位（`ItemBaseDef.slot`）ごとに1つ装備できる。拾ったとき、その部位が空か、いまのものよりレアリティの `tier` が高ければ自動で装備する（同じ tier なら付け替えない）。外れたものは捨てる（持ち物に積まない）
   - 通貨：数だけ数える
   - `equipment_stats() -> StatBlock`：装備中のすべての `total_stats()` を足した `StatBlock`
   - 信号 `changed`
2. **ドロップの出現と拾い** `scripts/loot/loot_director.gd`（`class_name LootDirector`、`extends Node`）
   - `setup(manager: EnemyManager, player: Node2D, parent: Node2D, stash: Stash, level_provider: Callable)`。`level_provider` は呼ぶと現在のプレイヤーのレベル（int）を返す
   - `enemy_hit` が `killed` のとき、`LootRoller.roll_drops(enemy.definition, level)` を呼び、結果を倒した位置のまわりに少しばらして地面に出す
   - ジェム・装備は、地面に小さな印（仮の絵）として出す。装備はレアリティの色。**使い回し（プール化）**で作る。通貨は、飛んでプレイヤーに吸い寄せられて自動で拾う（拾うまでの時間は短く）
   - プレイヤーが拾える範囲に入ったら拾う（ジェム・装備とも歩いて重なれば拾う。拾い範囲は定数）。拾ったら `Stash` に入れる
   - レアリティの `beam` が真の装備は、光の柱（縦に伸びる細い明るい線。仮の絵でよい。音は無し）を出す
   - 同時に地面に出ている数に上限を設ける（上限を超えたら古いものから消す）。大量に倒しても重くならない作りにする
3. **画面の表示** `scripts/ui/loot_hud.gd`（`class_name LootHud`、`extends CanvasLayer`）：`setup(stash: Stash)`。右上のやや下に、通貨の数と、直近に拾ったものの名前を3行ほど（装備は `display_name()`、色はレアリティの色。ジェムは `name`。数秒で消える）。見た目は仮でよい
4. **スキル装備画面との接続**：`scripts/ui/skill_screen.gd` に `stash: Stash` を足す（`setup` の引数は既存の呼び出しを壊さないよう、省略可能な引数にする。省略したら従来どおり `DataDB` の全部を出す）。`_available_skills()` / `_available_supports(slot)` は、`stash` があれば持っているものだけを出す。既存のテスト（`tests/test_skill_screen.gd`）が通ること、持ち物の分を足すこと
5. **テスト** `tests/test_loot_drops.gd`：自動装備の入れ替え（tier が高ければ替わる、同じなら替わらない）、`equipment_stats` の合計、ジェムの重複、`killed` でないときは何も落ちない、`xp` 0 の敵は何も落ちない、地面の数の上限、プール再利用、拾い範囲の判定（見た目を描かない部分だけでよい）

## 仕様（企画書から）
- 大量に倒すと大量に落ちる。通貨と素材は自動で拾い、装備は地面にこぼれる
- レアリティは段階に分ける。最上位2段階だけ光の柱と専用の音（音は今回やらない）
- ドロップ：ジェムと、付与効果1〜2個の装備（プロトタイプの範囲）。フィルター・分解・クラフト・本格的なインベントリはプロトタイプに入れない
- 運任せにしない方針（入手は交換やボス報酬もあるが、それはプロトタイプの外）

## 完了の条件
- Godot で起動でき、エラーが出ない。`tests/run_tests.gd` が失敗0（既存のテストも通ること）
- 敵を倒すと地面にドロップが出て、歩いて拾えること。この動作は、確認用の小さな画面（`scenes/test/` に置いてよい。その場合は最後の報告に書く）を作り、`tools/capture/capture.gd` で撮って最後の報告に添える
- 最後の報告に、`main.gd` でつないでほしいこと（`LootDirector.setup` の引数に何を渡すか、`Stash.equipment_stats()` をどこに足すか）を具体的に書く

## やらないこと
- `scripts/main/main.gd` `scripts/player/` `scripts/enemies/` `scripts/skills/` の変更（つなぎ込みは Claude がやる）
- 光の柱の音・効果音、フィルター、分解、クラフト、持ち物の画面、セーブ
- 新しいスキル・補助ジェム・装備のデータの追加
