# 指示書（tasks/）

配布スクリプトで各AIに配る指示書です。書き方は `_template.md`、配り方は `tools/dispatch/README.md`。

## プロトタイプの配る順番

| 波 | タスク | 担当 | 前提 |
| --- | --- | --- | --- |
| 0 | T00a〜d スモークテスト | 全員 | 配布の仕組みが各AIで動くかの確認。最初に1回 |
| 1 | T04 参考作の分析 | Gemini | なし |
| 1 | T06 敵の大量表示の負荷テスト | Codex | なし |
| 1 | T09 ダメージ計算・レベル | Claude | なし |
| 1 | T12 数値の初期値 | Gemini | なし |
| 1 | T14 ドロップの抽選 | Codex | なし |
| 1 | T17 デバッグ用の操作 | Muse Code | なし |
| 1 | T13 テキスト生成 | Muse（アプリ・手作業） | `manual/T13-muse-text.md` を貼る |
| 2 | T08 敵AI | Codex | T06 |
| 2 | T10 スキル実行（ジェム・補助・チェイン） | Claude | T09 |
| 3 | T11 スキル装備画面 | Codex | T10 |
| 3 | T18 撃破演出 | Codex | T08 |

第2波・第3波の指示書は、第1波の結果を見てから Claude が書きます。

```sh
# 第1波をまとめて配る（Git Bash で）
tools/dispatch/dispatch.sh tasks/T04-*.md tasks/T06-*.md tasks/T09-*.md tasks/T12-*.md tasks/T14-*.md tasks/T17-*.md
```
