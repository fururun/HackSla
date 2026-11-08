---
id: T25
agent: codex
title: UIの見た目を整える（パネルの統一・HUD・スキルバーの追加）
allowed: scripts/ui/ scenes/test/ tests/test_ui_style.gd tests/test_skill_screen.gd tests/test_equip_screen.gd
---

## 目的
遊んだ人から「見た目をもう少し整えてほしい」という声があった。UIは、いま画面ごとに別々の仮の見た目（色・枠・文字の大きさがばらばら）。同じ見た目のルールにそろえ、見やすくする。あわせて、いま何のスキルが使えるか・再使用まであと何秒かを常に見せる「スキルバー」を足す（エフェクトが分かりづらいという声への補助にもなる）。

## 前提（すでにあるもの）
- 画面（`scripts/ui/`）：`hud.gd`（左下の体力・経験値の棒、死亡メッセージ）、`loot_hud.gd`（右上の通貨と取得の表示）、`skill_screen.gd`（K：スキル装備画面）、`equip_screen.gd`（I：装備画面）、`damage_number.gd`（ダメージ数字）。デバッグ表示は `scripts/debug/debug_overlay.gd`（このタスクでは触らない）
- 画面は 480x270 の論理サイズ。いまは実解像度（1440x810）で描かれる（日本語の文字がくっきり出る）。文字の大きさは論理サイズで 8〜10 が基準
- `SkillCaster`（`scripts/skills/skill_caster.gd`）：`loadout`（`SkillLoadout`：`skill(slot)`、`support(slot)`、`skill_id(slot)`）、`cooldown_left(slot)`（残り秒）、`last_skill`。`SkillDef`（`name`、`element`、`kind`、`cooldown`）。属性の色は `CombatConsts.ELEMENT_COLORS`
- レアリティの色は `RarityDef.color`

## やること
1. **見た目のルールを1か所にまとめる** `scripts/ui/ui_style.gd`（`class_name UiStyle`）：パネルの背景・枠・文字・強調・警告の色、余白、文字の大きさ（標準・見出し・小さい補足）を `const` で定義し、パネル用の `StyleBoxFlat` を返す `static func`（例 `panel()`、`bar_background()`）と、ラベルに文字の見た目（色・縁取り）を当てる `static func` を持つ。落ち着いた暗い青灰色の基調、強調はやわらかい金色（既存の画面の雰囲気を保つ）
2. **既存の画面を `UiStyle` に移す**：`hud.gd`、`loot_hud.gd`、`skill_screen.gd`、`equip_screen.gd` が `UiStyle` の色・枠・文字の大きさを使うよう直す。パネルには、1ドットの枠、角の丸めなし、内側の余白を付ける。文字の大きさをそろえる（標準 10、見出し 12、補足 8 を目安に。読みづらければ調整してよい）。画面の中身と操作の仕方は変えない
3. **HUDの棒**：体力・経験値の棒に、枠と、中の明るい面・暗い面（上半分を少し明るく）を付けて立体感を出す。体力が少なくなったら（3割以下）棒が赤く点滅する（遅く。0.6秒周期くらい）
4. **スキルバー** `scripts/ui/skill_bar.gd`（`class_name SkillBar`、`extends CanvasLayer`）：`setup(caster: SkillCaster)`。画面の下中央に、スキル枠1〜3（`SkillLoadout` の枠数ぶんではなく、いま入っている枠。空の枠は暗い空枠）を横に並べる。各枠に：属性の色の角丸でない四角、スキル名の頭1文字（または2文字）、操作の表示（枠1「左」、枠2「右」、枠3「Q」、枠4「E」…。操作のキーは `scripts/core/input_setup.gd` の割り当てに合わせる）、補助ジェムが付いていれば右下に小さな点、再使用時間中は下から上へ暗い膜がかかって残り秒数を出す（`cooldown_left`）。使える状態になった瞬間に、枠が一瞬明るく光る。チェイン技が出せる状態（`caster.chain.preview(...)` が使える。使い方は `skill_caster.gd` と `scripts/skills/chain_tracker.gd` を読む）の枠は、枠の縁が光る
5. **ダメージ数字**：`damage_number.gd`（T18 でプール化済み）を、太めの縁取りと、ダメージが大きいほど少し大きく・黄色くなるように直す（しきい値は `scripts/ui/` の中の定数）。プールの仕組み・同時数の上限は壊さない
6. **確認用の画面**：`scenes/test/` に、全部の画面（HUD・スキルバー・ルート HUD・取得の表示・装備画面・スキル装備画面）を見られる確認用の画面（またはスクリプト）を作る。既存の `hud_demo`、`loot_demo`、`skill_screen_demo` など（`scenes/test/` 内）を直してよい
7. **テスト** `tests/test_ui_style.gd`：`UiStyle` の色・サイズの定義が揃っていること、パネル用のスタイルが作れること、スキルバーが枠の数ぶんの表示を持つこと、再使用中・使用可能の状態の判定（描画しない部分だけ）。既存のスキル装備画面・装備画面のテストが通ること

## 仕様（企画書から）
- スキル枠の操作：スキル枠1＝左クリック、2＝右クリック、3〜6＝Q/E/R/F
- スキルチェイン：発見済みのチェインが出せるときだけ、スキル枠のアイコンが光る（未発見のチェインは出さない。`ChainTracker.preview` は発見済みだけを返す）
- 操作の割り当ては `scripts/core/input_setup.gd` が正（変更しない）

## 完了の条件
- Godot で起動でき、エラーが出ない。`tests/run_tests.gd` が失敗0（既存のテストも通ること）
- 確認用の画面を `tools/capture/capture.gd`（`--scene=` と `--out=` を指定。既定の倍率は 1）で撮り、全部の画面の画像を最後の報告に添える。**自分で画像を見て**、文字が読めること・画面同士の見た目がそろっていること・文字や枠がはみ出していないことを確かめて、まだ気になる点を報告に書く
- 最後の報告に、`main.gd` でつないでほしいこと（`SkillBar.setup` に何を渡すか）を具体的に書く

## やらないこと
- `scripts/main/main.gd`、`scripts/skills/`、`scripts/combat/`、`scripts/enemies/`、`scripts/world/`、`scripts/debug/` の変更（つなぎ込みは Claude がやる）
- 画面の操作・内容の変更（装備の付け替えの仕組みなど）、新しい画面の追加（スキルバー以外）
- 画像（アイコン・フォント）の追加。文字はいまのフォントのまま
- 音
