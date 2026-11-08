---
id: T21
agent: codex
title: 装備の変化を分かりやすく見せる（装備画面・拾った時の表示・地面の名前）とジェムの重複対策
allowed: scripts/ui/equip_screen.gd scripts/ui/loot_hud.gd scripts/loot/ scripts/core/input_setup.gd tests/test_equip_screen.gd tests/test_loot_drops.gd tests/test_loot.gd
---

## 目的
遊んだ人から「装備を拾っても、変わったのか分かりにくい」「別のスキルがないと、ジェムを拾った意味がない」という声があった。1つ目は、拾った装備で何がどう変わったかを見えるようにして直す。2つ目の「別のスキル」を増やすのは別のタスク（T22、データ）がやる。このタスクでは、すでに持っているジェムばかりが落ちて無駄にならないようにする。

## 前提（すでにあるもの）
- `scripts/loot/stash.gd`（`Stash`）：装備は部位ごとに1つ。拾うと、その部位が空かレアリティの `tier` が高ければ自動で装備する。`collect(value)`、`equipment_stats() -> StatBlock`、信号 `changed`、`picked_up(value)`
- `scripts/loot/loot_director.gd`（`LootDirector`）、`ground_drop.gd`（地面に出ているドロップ1つ。プール化）、`scripts/ui/loot_hud.gd`（通貨と直近の取得3件）
- `scripts/loot/loot_roller.gd`（`LootRoller`）：`roll_drops(enemy, level)`、`_roll_gem()`（`DataDB.droppable_skills()` から重みで選ぶ）
- `scripts/loot/item_instance.gd`：`base`（`ItemBaseDef`：`slot` など）、`rarity`、`affixes`、`total_stats() -> Dictionary`（キーは `life` `armor` `damage_pct` など。`docs/data_schema.md` の stat の表を読む）、`display_name()`
- `scripts/ui/skill_screen.gd`（T11）の画面の作り方・見た目の作法を、新しい画面でも合わせる
- プレイヤーのステータスの入れ物は `player.caster.stats`（`StatBlock`）。体力は `player.vitals`（`max_life()`）。このタスクでは `main.gd` を触らず、画面は `setup(...)` を持つ部品として作る（つなぐのは Claude）

## やること
1. **ステータスの表示名** `scripts/loot/stat_labels.gd`（`class_name StatLabels`、`const` と `static func`）：stat のキーを日本語の表示名にする（例 `life` → 「最大ライフ」、`armor` → 「防御」、`damage_pct` → 「ダメージ」）。値の見せ方も1か所にまとめる（`_pct` や `_res` のものは「+12%」、`life` などは「+30」）。表に無いキーはキーのまま出す。`docs/data_schema.md` の stat の全キーを網羅する
2. **拾った装備の表示を変える**：`Stash` が自動で装備を替えたとき、`loot_hud.gd` の取得の表示を「装備した：〈新しい装備名〉」にし、続けて、前の装備と比べた変化を行ごとに出す（例：「最大ライフ +30」「防御 −5」。増えた行と減った行で色を変える）。前の装備が無いときは、新しい装備の全ステータスを「+」で出す。装備せずに捨てた（弱かった）ときは「見送り：〈名前〉」を暗い色で出す。表示は数秒で消える。そのために `Stash` に、装備を替えたとき・見送ったときに出る信号（`equipped(slot, new_item, old_item)` / `skipped(item)` など。名前は任せる）を足す
3. **装備画面** `scripts/ui/equip_screen.gd`（`class_name EquipScreen`、`extends CanvasLayer`）：`setup(stash: Stash, vitals: PlayerVitals)`、`open()` / `close()` / `toggle()`。入力 `toggle_equip_screen`（キーは I）は `scripts/core/input_setup.gd` に足し、`_unhandled_input` で受けて開閉する（`SkillScreen` の作りと同じ。開いている間はゲームを止める）
   - 左：6つの部位（`weapon` `armor` `helmet` `boots` `ring` `amulet`）ごとに、装備中の名前（レアリティの色）と、その装備の主なステータス。空の部位は「—」
   - 右：いまの合計。装備全体のステータス合計（`StatLabels` で表示）と、最大ライフ（`vitals.max_life()`）
   - 部位をクリックすると、その装備の付与効果を全部一覧に出す（付与効果の名前と値）
   - 開いているあいだ `stash.changed` を受けて表示を更新する
4. **地面の装備の名前**：`ground_drop.gd` が装備の場合、プレイヤーが近く（一定の距離。定数）にいるときだけ、その装備の名前（レアリティの色）を印の上に小さく出す。離れたら消す。大量に出ていても重くならない作りにする（表示するのは近いものだけ。毎フレーム全部に文字を作り直さない）
5. **ジェムの重複対策**：`LootRoller.roll_drops` に省略可能な引数 `owned_gems`（持っているジェムの集合。`Stash.has_gem` で調べる形に合わせてよい）を足す。持っていないジェムの重みを `GEM_NEW_WEIGHT_MULT`（定数、4.0）倍にして、持っていないジェムが出やすくなるようにする。`LootDirector` はその引数を渡す。引数を省略したときは、これまでと同じ動き（既存のテストが通ること）。また、持っているジェムを拾ったとき、取得の表示に「所持済み」と出し、通貨を少し増やす（`GEM_DUPLICATE_CURRENCY`、定数、5）
6. **最初に持っている補助ジェムを固定する**：いまの `Stash` は、最初から補助ジェムを `DataDB` の全部持つ作りになっている。T22 で補助ジェムが増えるので、最初に持つのは既存の2つ（`scatter` と `burst_on_kill`）だけにし、`Stash.STARTING_SUPPORT_IDS`（`const` の配列）にまとめる。新しい補助ジェムはドロップで手に入るようにする（`LootRoller._roll_gem` が補助ジェムも候補にしているか確認し、していなければ候補に入れる）。スキルの最初の所持（`slash` `frost_bloom` `fire_bolt`）はそのまま
7. **テスト** `tests/test_equip_screen.gd`：`StatLabels` の表示名と値の整形（全キーが日本語になる）、装備を替えたときの変化の行（増減・前の装備なし）、`Stash` の信号、装備画面が持つ部位の表示（描かずに調べられる範囲）。`tests/test_loot_drops.gd` / `tests/test_loot.gd`：持っていないジェムが出やすくなる（`owned_gems` を渡すと、出る確率の偏りが出ること）、重複したときの通貨

## 仕様（企画書から）
- 大量に倒すと大量に落ちる。通貨と素材は自動で拾い、装備は地面にこぼれる。拾った装備を選別する流れが面白さの元（フィルター・分解・クラフトは今回やらない）
- 数値・名前はデータが正。表示名の表（`StatLabels`）は画面の文言なのでコードに置いてよい

## 完了の条件
- Godot で起動でき、エラーが出ない。`tests/run_tests.gd` が失敗0（既存のテストも通ること）
- 確認用の小さな画面（`scenes/test/` に置いてよい。その場合は最後の報告に書く）を作り、`tools/capture/capture.gd` で撮って、装備画面と、装備を替えた直後の表示、地面の名前の見え方の画面を最後の報告に添える
- 最後の報告に、`main.gd` でつないでほしいこと（`EquipScreen.setup` に何を渡すか）を具体的に書く

## やらないこと
- `scripts/main/main.gd` `scripts/player/` `scripts/enemies/` `scripts/skills/` `scripts/stats/` の変更
- 新しいスキル・補助ジェム・装備のデータの追加（T22）
- 装備の見た目をキャラクターの絵に反映する（ドット絵が入ってから）
- 持ち物の画面、装備の付け替え操作、フィルター、分解、クラフト
