# balance_logs

バランス調整用の記録です。ゲームを遊ぶと、1回のプレイ（スタートから、やり直し・やられた・終了まで）ごとに、
`runs.jsonl` に1行（1つのJSON）が書き足されます。消さずに残して、あとで集計します。

- 集計：`python tools/balance/summarize_runs.py`
- 項目の意味：`docs/balance_log.md`
- 同じものが、`%APPDATA%\Godot\app_userdata\HackSla\logs\balance_runs.jsonl` にも書かれます。
