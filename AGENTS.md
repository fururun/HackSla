# AGENTS.md — 全AI共通のルール

Claude / Codex / Gemini / Muse Code は、作業の前に必ずこのファイルを読んでください。

## このプロジェクト

- 2Dドット絵・斜め見下ろし視点のハクスラ「HackSla」。Godot 4.7 / GDScript
- 企画の要点：`docs/concept.md`（必読）
- いま作っているもの：`docs/prototype.md`（プロトタイプの範囲）
- データの書き方：`docs/data_schema.md`

## やらないこと（企画の方針）

- サバイバー系ローグライトにしない（時間で湧き続ける敵、自動攻撃、毎回リセットされる成長はNG）
- 参考作（POE2、ディアブロ、ルミナキューブなど）は「仕組み」だけ参考にする。名前・文章・数値・配置・絵を写さない
- プロトタイプの範囲（`docs/prototype.md` の「入れないもの」）を勝手に広げない

## 作業のルール

- 変更してよいのは、指示書の `allowed` に書かれた場所だけ。それ以外が必要なら、変更せずに報告に書く
- `.tscn` は、そのタスクの担当以外は編集しない
- 数値（スキル・装備・敵）は `data/` の JSON に置き、コードに直接書かない
- git の commit / push / PR作成はしない（配布スクリプトが行う）
- 作業の最後に「やったこと」「確認方法」「気になる点」を短くまとめる
- 「できました」と書く前に、下の「確認」を実際に実行する。実行できなかったら、そう書く

## 確認（作業の最後に必ず）

`godot` は Godot 4.7 の実行ファイルのこと。配布スクリプトから起動されたときは、プロンプトに場所が書いてあります（環境変数 `$GODOT` にも入っています）。

```sh
godot --headless --import                                   # 初回・ファイル追加後
godot --headless --script res://tests/run_tests.gd          # テスト（失敗0であること）
godot --headless --quit-after 300                           # メイン画面が5秒エラーなく動くこと
```

見た目が変わる作業は、画面を撮って変更前と比べる：

```sh
godot --script res://tools/capture/capture.gd -- --out=shots/after.png
```

## コードの書き方

- GDScript は型を付けて書く（`var hp: float = 10.0`、`func f(x: int) -> void:`）
- 新しいクラスは `class_name` を付け、1ファイル1クラス
- 敵・弾・エフェクト・ダメージ数字など大量に出るものは、使い回し（プール化）前提で作る。敵に物理演算（CharacterBody2D / RigidBody2D）は使わない
- 斜め視点の距離は `Iso.ground_distance()`（縦を2倍にして測る）。向きは `Facing`（8方向）
- 当たり判定の対象は `enemies` グループ。敵は `take_hit(amount: float, skill: SkillDef)` を持つ
- ファイル名・ノード名は snake_case。コメントは日本語でよい
- 新しい処理にはテストを `tests/test_*.gd` に足す（`test_` で始まる関数を書くだけで実行される）

## フォルダ

| 場所 | 中身 |
| --- | --- |
| `scenes/` | シーン（.tscn） |
| `scripts/core/` | 起動時の設定（操作の割り当てなど） |
| `scripts/data/` | データの型（`defs/`）と読み込み（`DataDB`） |
| `scripts/player/` `scripts/enemies/` `scripts/combat/` `scripts/skills/` `scripts/world/` `scripts/ui/` | 各機能 |
| `data/` | 数値（JSON）とマップ |
| `art/` | 絵（`concept/` 下書き、`sprites/` 仕上げ、`fx/` エフェクト） |
| `tests/` | テスト |
| `tasks/` | AIへの指示書 |
| `tools/dispatch/` | 指示書の配布と監視ボード |
| `tools/capture/` | 画面の撮影 |
