---
id: T11
agent: codex
title: 簡易スキル装備画面（スキル枠・補助ジェム・チェイン図鑑）
allowed: scripts/ui/skill_screen.gd scripts/ui/skill_screen/ scenes/test/skill_screen_demo.tscn scenes/test/skill_screen_demo.gd scripts/core/input_setup.gd tests/test_skill_screen.gd
---

## 目的
スキル枠にスキルと補助ジェムを付け替える画面を作る。「補助ジェムを付け替えたら強くなった実感があるか」を確かめるための、簡易な画面（見た目は仮でよい）。

## 前提（すでにあるもの）
- `scripts/skills/skill_loadout.gd`（`SkillLoadout`）：枠は1〜6。`skill_id(slot)` / `support_id(slot)` / `set_skill(slot, id)` / `set_support(slot, id)` / `clear_skill` / `clear_support`、信号 `changed(slot)`。付けられない組み合わせは `false` を返す
- `scripts/skills/skill_caster.gd`（`SkillCaster`）：`loadout`（上の `SkillLoadout`）と `chain`（`ChainTracker`、`discovered` に発見済みチェインの id が入る）を持つ
- `DataDB`：`DataDB.skills`（辞書 id→`SkillDef`）、`DataDB.supports`（同 `SupportDef`）、`DataDB.chains`（`Array[ChainRule]`）、`SkillDef.chain_only`、`SupportDef.can_support(skill)`、`SupportDef.kinds`
- 文字は小さいドット絵向けの画面サイズ（`project.godot` の設定を確認。フォントは 8 前後）。既存の仮の絵・仮の色の作法は `scripts/debug/debug_overlay.gd`（T17）を参考にする

## やること
1. `scripts/ui/skill_screen.gd`（`class_name SkillScreen`、`extends CanvasLayer`）を作る
   - `setup(caster: SkillCaster) -> void`、`open()`、`close()`、`toggle()`、`is_open() -> bool` を持つ
   - 開いている間は、ゲームを止める（`get_tree().paused = true`）。この画面は止まった中でも動くように `process_mode` を設定する。閉じたら元に戻す
2. **スキル枠の表示**：プロトタイプの範囲は「スキル枠2、補助枠各1」。枠の表示数は `SkillScreen.VISIBLE_SLOTS`（定数、いまは 2）で決める。それぞれに、スキル名と補助ジェム名（空なら「—」）と、属性・種類が分かる表示
3. **付け替え（マウスだけで操作）**
   - 枠のスキルの部分をクリック → 選んだ状態になり、右の一覧に「付けられるスキル」を出す（`chain_only` のスキルは出さない）。一覧をクリックして `set_skill`。右クリックで外す（`clear_skill`）
   - 枠の補助の部分をクリック → 一覧に「その枠のスキルに付けられる補助ジェム」だけを出す。クリックで `set_support`、右クリックで外す
   - 一覧にスキル・補助ジェムの `name` と `description` を出す。数値（ダメージなど）は説明文に書かない。`SkillDef` / `SupportDef` から読んだ値を、一覧の下に小さく表示する（例：ダメージ、再使用時間、補助ジェムなら `modifiers` の効果）
   - いまは持ち物（インベントリ）の仕組みがない。一覧には、`DataDB` にある付けられるものを**すべて**出す。あとで持ち物に差し替えられるよう、一覧を作る処理は `_available_skills()` / `_available_supports(slot)` のような別の関数に切り出す
4. **チェイン図鑑**：画面の下か横に小さく出す。`DataDB.chains` のうち発見済み（`caster.chain.discovered`）は名前と説明、未発見は「？」だけ（企画書：未発見は「？」で数だけ出す）。発見済み・未発見の数も表示
5. **開く操作**：`scripts/core/input_setup.gd` に入力 `toggle_skill_screen`（キーは K）を足す。この入力を処理するのは `main.gd` の担当外の話なので、この画面を使うのは次の方法にする：`SkillScreen` は自分の `_unhandled_input` で `toggle_skill_screen` を受け取って開閉する
6. **確認用の画面**：`scenes/test/skill_screen_demo.tscn`（と `.gd`）を作る。`SkillCaster` を1つ作り、チェインを1つ発見済みにしておき、`SkillScreen` を開いた状態で表示する。`capture.gd` で撮れること
7. **テスト**：`tests/test_skill_screen.gd` を作る。画面を描かずに調べられる部分だけでよい（`_available_skills()` に `chain_only` が出ない、補助ジェムの一覧がスキルの種類で絞られる、付け替えるとロードアウトが変わる、付けられない組み合わせは変わらない、図鑑の発見数）

## 仕様（企画書から）
- スキル装備画面：キャラ専用。枠に上限がある（序盤はスキル枠2・補助0 → 終盤はスキル枠6・補助4〜5、仮）。補助ジェムは、スキル枠の横の補助枠にはめると、そのスキルだけ性能が変わる
- スキルチェイン：発見済みのものだけ図鑑に見せる。未発見は「？」で数だけ。一度出したものはチェイン図鑑で確認できる
- 操作：スキル枠1＝左クリック、2＝右クリック、3〜6＝Q/E/R/F。移動は WASD
- 数値・名前はデータが正。コードに直接書かない（画面の文言と見た目の数値は、画面のコードに定数としてまとめてよい）

## 完了の条件
- Godot で起動でき、エラーが出ない。`tests/run_tests.gd` が失敗0（既存のテストも通ること）
- `godot --script res://tools/capture/capture.gd -- --scene=res://scenes/test/skill_screen_demo.tscn --out=shots/T11.png` で、画面が撮れる。撮った画面を最後の報告に添える
- 最後の報告に、画面の見え方と、付け替えのやり方（どこをクリックするか）を書く

## やらないこと
- `scripts/main/main.gd` の変更（メイン画面への組み込みは、Claude があとでやる）
- 持ち物（インベントリ）、ドロップとの接続、ジェムのレベル
- ドラッグ＆ドロップ、キーボードでの操作、アニメーション
- スキルツリー・クラフト（プロトタイプに入れない）
- `scripts/skills/` `scripts/enemies/` の変更（読むだけ）
