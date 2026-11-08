---
id: T22
agent: gemini
title: スキルと補助ジェムを増やす（データの追加）
allowed: data/skills/ data/supports/ data/chains/ data/text/ tests/test_data.gd docs/balance.md
---

## 目的
遊んだ人から「別のスキルがないと、拾ったジェムの意味がない」という声があった。いまスキルは3つ（払い太刀・霜囲い・火だま打ち）＋チェイン技（霜砕き）、補助ジェムは2つ（三つ又・はじけ仕舞い）しかなく、ドロップしても新しいものが出ない。ドロップで手に入る新しいスキルと補助ジェムを、データだけで増やす。

## 前提（すでにあるもの）
- データの書き方：`docs/data_schema.md`（必ず全部読む。キーは表にあるものだけ使う）
- いまのデータ：`data/skills/skills.json`、`data/supports/supports.json`、`data/chains/chains.json`。数値の方針と判定の仕方は `docs/balance.md`（読んで合わせる）
- 表示名と説明文：`data/text/names.json`（Muse が作った候補集。`entries` に `category`（`skill` / `support` など）、`id`、`adopted`（採用中の案の番号）、`candidates`（案ごとに `display_name` `reading` `description`）がある。既存の書き方をそのまま真似る）
- スキルを実際に出す仕組み（`scripts/skills/skill_caster.gd`）は、スキルの `kind` が `melee`（近接の扇形）、`area`（足元の円）、`projectile`（飛び道具）の3種類だけ動く。`movement` と `totem` は動かないので使わない。補助ジェムの `modifiers` は `data_schema.md` の表にあるキーだけ動く
- 新しいスキルは `chain_only: false` で、ジェムとして落ちるようにする（`droppable_skills` が拾う）

## やること
1. **スキルを5つ追加**（`data/skills/skills.json`）。次の組み合わせにして、遊んだときに違いが分かるようにする
   - 火の範囲攻撃（`element: fire`、`kind: area`）：群れをまとめて焼く
   - 氷の飛び道具（`element: cold`、`kind: projectile`）：霜囲いの凍結とチェインしやすい
   - 雷の飛び道具（`element: lightning`、`kind: projectile`）：射程が長く、1発が軽い
   - 物理の範囲攻撃（`element: physical`、`kind: area`）：自分の周りを大きく叩く。再使用時間は長め
   - 物理の近接（`element: physical`、`kind: melee`）：範囲は狭いが、ダメージが大きく射程が長い突き
   - どれも `docs/balance.md` の数値の考え方（ダメージ・再使用時間のバランス）に合わせる。「新しいスキルが強すぎて他が無意味」「弱すぎて拾う意味がない」にならないよう、1回あたりのダメージ×1秒あたりの発動回数を、いまのスキルの 0.8〜1.3倍の範囲に収める。違いは数値の大小ではなく、範囲・射程・属性・使い心地で出す
2. **補助ジェムを4つ追加**（`data/supports/supports.json`）。いまの2つと重ならない効果にする
   - ダメージを上げる代わりに再使用時間が伸びる（`damage_mult` と `cooldown_mult`）
   - 範囲が広がる代わりにダメージが少し下がる（`area_mult` と `damage_mult`。`kinds` は `area` と `melee`）
   - 飛び道具が当たった後に近くの敵へ伝わる（`hop_count`。`kinds` は `projectile`）
   - 再使用時間が短くなる代わりにダメージが下がる（`cooldown_mult` と `damage_mult`）
   - 補助ジェムは「強くなった実感」が出る数値にする（効果が分かりにくい小さな差にしない）。ただし 1 個で他を食いつぶす強さにしない
3. **チェインを1つ追加**（任意。チェイン技のスキルは `chain_only: true` にして、新しいスキルとは別に1つ足す）：`data/chains/chains.json` に、新しい氷の飛び道具や雷の飛び道具を使った組み合わせを1つ。タグの組み合わせ（例 `["cold","area"]` → `["projectile"]` のように）か、特定スキル同士。発見のしがいがあるものにする。難しければ足さなくてよい（足さない場合は、報告に理由を書く）
4. **表示名と説明文**（`data/text/names.json`）：追加したスキル・補助ジェム・チェイン技のぶんの `entries` を、既存と同じ書式（案は **1つだけ**、`adopted: 1`、`plan: 1`）で追加する
   - 命名ルール：日本語のみ。短く声に出して読みやすい名前。難しい漢字には `reading`（読み仮名）を付ける。既存のゲーム作品の固有名詞・造語を使わない。特定の神話・宗教・実在の地名に寄せない。英語・カタカナの格好付けをしない。説明文は一行で、何が起きるかが分かる文にし、数値は書かない
   - 既存の名前（払い太刀など）とは語感が揃うようにする（和語寄りで、やわらかく短い）
   - これらの名前は「仮」。最後の報告に「名前は仮で、あとで見直す想定」と書く
5. **テスト**：`tests/test_data.gd` に、新しいスキル・補助ジェムが `DataDB` に読み込まれ、`droppable_skills()` に新しいスキルが入ること、補助ジェムの `kinds` の整合、名前が全部入っていることを足す。既存のテストが通ること
6. `docs/balance.md` に、追加したものの狙いと数値の根拠を短く書き足す（既存の書式に合わせる）

## 完了の条件
- Godot で起動でき、エラーが出ない。`tests/run_tests.gd` が失敗0。`DataDB` の読み込みエラーが出ないこと
- 最後の報告に、追加したものの一覧（id・名前・要点）を表にして書く

## やらないこと
- コード（`scripts/`）の変更。データだけで増やす。動かないキー・`kind` は使わない
- いまあるスキル・補助ジェム・チェインの数値の変更
- 敵・装備のデータの変更
- 名前の案を複数作ること（1つだけ）
