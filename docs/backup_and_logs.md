# 自動バックアップとログ

## 自動バックアップ

コミットのたびに、自動でバックアップを取る（`.git/hooks/post-commit` → `tools/backup/backup.sh`。バックグラウンドで動くので、コミットは遅くならない）。

| 取るもの | 置き場所（既定） |
| --- | --- |
| 全ブランチの全履歴（`HackSla_<日時>_<コミット>.bundle`） | `C:\Users\furur\Documents\HackSla-backups\` |
| AIへの指示・結果のログ（`dispatch_<日時>.tar.gz`、`.dispatch/` の中身） | 同上 |
| いつ・何を取ったかの記録（`backup.log`） | 同上 |

- 残す数は30世代。古いものは自動で消える。直前から120秒以内のコミットは、取らずに飛ばす（連続コミットで増えすぎないように）。
- 別のドライブにも置きたいときは、環境変数 `HACKSLA_BACKUP_DIR` に場所を入れる（ディスクが壊れても残る）。数は `HACKSLA_BACKUP_KEEP`、間隔は `HACKSLA_BACKUP_MIN_GAP`（秒）。
- 手で取る：`FORCE=1 tools/backup/backup.sh`
- フックを入れる・外す：`tools/backup/install_hook.sh` / `tools/backup/install_hook.sh --remove`（フックは git に入らないので、別のPCではそこでもう一度入れる）
- **元に戻す**：`git clone <bundleのパス> HackSla_restored`
- コミットしていない変更は、バックアップに入らない（コミットしてから取る仕組みのため）。

## ログ（ゲームを動かしたとき）

`scripts/core/game_log.gd`。ゲームを起動するたびに、2つのファイルができる。

| ファイル | 内容 |
| --- | --- |
| `play_<日時>.log`（遊んだ記録） | 起動、宝箱を開けた、拾ったもの、レベルアップ、25体ごとの撃破数、ボス撃破、死亡、スキルの初めてのチェイン、終了時のまとめ（時間・撃破・死亡・レベル・拾った数・スキルごとの使用回数） |
| `debug_<日時>.log`（デバッグの記録） | エンジンのエラー・警告（エラー内容と場所つき）、10秒ごとの状態（FPS・敵の数・体力・位置・撃破数）、FPS が 40 を下回ったときの警告 |

- 場所：`%APPDATA%\Godot\app_userdata\HackSla\logs\`（Godot のメニュー「プロジェクト → ユーザーデータフォルダを開く」でも開ける）。
- 種類ごとに、新しい順に20個だけ残す（古いものは自動で消える）。
- テストと撮影（`--script`）で動かしたときは、遊んだログと混ざらないよう、`logs_tools\` に書く。
- 出来事を増やすには、`game_log.gd` の `setup()` で信号をつなぎ、`play("名前", {...})` を呼ぶ。
