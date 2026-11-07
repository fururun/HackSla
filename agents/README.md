# エージェント（各社の役割）

各社の中の「役割」ごとの心得です。指示書の `role:` に役割の名前を書くと、配布スクリプトがその心得を指示の前に付けます。

| 会社 | 役割 | ファイル | 動かし方 |
| --- | --- | --- | --- |
| Claude社 | PM（発注と報告） | `claude/pm.md` | 会話で直接 |
| Claude社 | 設計（仕様と中核の実装） | `claude/design.md` | 会話で直接 |
| Claude社 | 検収（別の担当として確認） | `claude/acceptance.md` | 会話で直接 |
| Codex社 | 実装 | `codex/impl.md` | 配布スクリプト（`role: impl`、省略時もこれ） |
| Codex社 | テスト・相互チェック | `codex/test.md` | `role: test`、相互チェックのとき自動 |
| Codex社 | 性能（重さの計測と改善） | `codex/perf.md` | `role: perf` |
| Gemini社 | 調査（参考作） | `gemini/research.md` | `role: research` |
| Gemini社 | バランス（数値） | `gemini/balance.md` | `role: balance`（省略時もこれ） |
| Gemini社 | QA（相互チェック） | `gemini/qa.md` | 相互チェックのとき自動 |
| Muse社 | 情報集め／テキスト／画像の下書き／広報の下書き | `tasks/manual/` の依頼文 | アプリで手作業 |

役割が足りなくなったら、`agents/<会社>/<役割>.md` を足すだけで使えます。
