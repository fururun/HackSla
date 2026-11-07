# スキル（作業の手順書）

どのAIも読める、作業の手順書です。各社の役割（`agents/<会社>/<役割>.md`）に、読むべきスキルが書いてあります。

| スキル | 内容 | 主に使う役割 |
| --- | --- | --- |
| write-task | 指示書の書き方 | Claude社 PM |
| report-format | 発注一覧と検収結果の書き方 | Claude社 PM |
| acceptance-check | 検収の確認項目 | Claude社 検収 |
| add-data | data/ の数値の足し方・直し方 | Claude社 設計、Gemini社 バランス |
| gdscript-style | 型付きGDScriptの書き方 | Claude社 設計、Codex社 実装 |
| pooling | 使い回し（プール化） | Codex社 実装・性能 |
| iso-math | 斜め見下ろし視点の計算 | Claude社 設計、Codex社 実装 |
| write-tests | テストの書き方と実行 | 全員 |
| capture-screen | 画面の撮影 | Claude社 検収、見た目を変える担当 |
| reference-analysis | 参考作の分析（丸写し禁止の確認表） | Gemini社 調査 |
| balance-calc | DPS表と倒すまでの時間の計算 | Gemini社 バランス |
| cross-review | 相互チェックの手順 | Codex社 テスト、Gemini社 QA |

Muse社はアプリで手作業なので、手順書の代わりに依頼文の型を `tasks/manual/` に置いています。
