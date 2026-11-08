# AI配布キット（dispatch）

指示書（`tasks/*.md`）を書けば、Claude・Codex・Gemini・Muse Code に一斉に配って、
同時に作業させ、結果をブランチ・コミット・PRにまとめます。コピペは不要です。

```
tasks/T07.md ─┐                       ┌─ task/T07 ブランチ → PR
tasks/T12.md ─┼─ dispatch.sh ─ 同時起動 ┼─ task/T12 ブランチ → PR
tasks/T14.md ─┘                       └─ task/T14 ブランチ → PR
```

## 入っているもの

| ファイル | 役割 |
| --- | --- |
| `tools/dispatch/dispatch.sh` | 配布スクリプト本体 |
| `tools/dispatch/agents.conf` | 各AIの起動コマンド（ここだけ環境に合わせて直す） |
| `tools/dispatch/cleanup.sh` | 終わったタスクの作業場所とブランチを片付ける |
| `tools/dispatch/review.sh` | 納品物の検収OK・差し戻しを記録する |
| `tools/dispatch/crossreview.sh` | 納品物を、書いたAIとは別のAIに確認させる（相互チェック）。例：`crossreview.sh T06:gemini T09:codex` |
| `tools/dispatch/lib.sh` | 取引の記録（共通の関数） |
| `tools/dispatch/monitor/` | 監視ボード（`monitor.py` と `index.html`） |
| `tools/dispatch/mock/agent.sh` | 模擬AI（仕組みのテスト用） |
| `tasks/_template.md` | 指示書のテンプレート |
| `tasks/T00a〜d-smoke-*.md` | 4つのAIそれぞれのスモークテスト |
| `AGENTS.md` | 全AI共通のルールの雛形 |

## Windows で使うとき

- **Git Bash** で実行します（Git for Windows に付いてきます）。PowerShell やコマンドプロンプトでは動きません
- 監視ボードは `python3` の代わりに `py` か `python` で起動します：`py tools/dispatch/monitor/monitor.py`
- `agents.conf` の `GODOT_BIN` に、Godot の実行ファイルの場所を書きます（`_console.exe` のほうを指定すると、AIがエラーを読めます）
- 改行コードは `.gitattributes` で LF に固定してあるので、そのままで動きます

## 準備（最初の1回）

1. このキットの中身を、ゲームのリポジトリ直下にコピーする
2. `.gitignore` に `.dispatch/` を追加する（ログ置き場）
3. 実行権限を付ける：`chmod +x tools/dispatch/*.sh tools/dispatch/mock/*.sh`
4. 各CLIを入れてログインしておく：`claude` / `codex` / `gemini` / `muse`
5. `agents.conf` のフラグを、各CLIの `--help` で確認する（特に Muse Code の自動承認）
6. PRまで作るなら：GitHubにリポジトリを置き、`gh auth login` を済ませる

## テストの手順（この順番で）

**① 仕組みだけ確認（AIは動かない）**
```sh
tools/dispatch/dispatch.sh --dry-run tasks/T00*.md
```
4件とも「→ 担当」と表示されればOK。

**② 模擬AIで並列実行を確認（AIは動かない・PRは作らない）**
```sh
tools/dispatch/dispatch.sh --mock --no-pr tasks/T00*.md
tools/dispatch/cleanup.sh T00a T00b T00c T00d
git branch -D task/T00a task/T00b task/T00c task/T00d   # テスト用なので消す
```
結果に4件とも ✓ が出ればOK。

**③ 本物のAIでスモークテスト（PRは作らない）**
```sh
tools/dispatch/dispatch.sh --no-pr tasks/T00*.md
```
- `.dispatch/logs/T00a.log` などで各AIの出力を確認
- 各作業場所（リポジトリの隣の `<名前>-worktrees/T00a/` など）に `docs/smoke/<AI名>.md` ができていればOK
- ✗ が出たAIは、ログを見て `agents.conf` のコマンドを直す（ログイン切れ・フラグ違いが多い）

**④ PRまで通す**
```sh
tools/dispatch/cleanup.sh T00a T00b T00c T00d && git branch -D task/T00a task/T00b task/T00c task/T00d
tools/dispatch/dispatch.sh tasks/T00*.md
```
GitHubに4本のPRが並べば完成です。確認したらPRは閉じてOK。

## 監視ボード（AI外注管理ボード）

各AIを外注先の会社に見立てて、発注から完了までの流れと作業状況をブラウザで見られます。

```sh
python3 tools/dispatch/monitor/monitor.py          # → http://localhost:8765
python3 tools/dispatch/monitor/monitor.py --lan    # 同じWi-Fiのスマホからも見る
```

| 画面の場所 | 見られること |
| --- | --- |
| 上の数字 | 作業中・検収待ち・要対応・今日の完了・発注準備の件数 |
| 取引先 | 会社ごとの稼働状況、受注・納品・差し戻し・失敗の数、平均納期、成功率 |
| 発注フロー | 発注準備 → 作業中 → 検収待ち → 完了（失敗・差し戻しは「要対応」） |
| 取引履歴 | 発注・着手・納品・検収・差し戻しの記録（新しい順） |
| カードを押す | 発注書（AIに渡した指示）と作業ログ、検収コマンド |

発注フローの段階は、自動で記録されるものと、自分で記録するものがあります。

| 段階 | 記録のされ方 |
| --- | --- |
| 発注準備 | `tasks/` に指示書を置くと表示 |
| 作業中 → 検収待ち／失敗 | `dispatch.sh` が自動で記録 |
| 検収OK／差し戻し | `tools/dispatch/review.sh T08 ok` ／ `review.sh T08 ng "理由"` |
| 完了 | ブランチがマージされたら自動。`cleanup.sh --merged` でも記録 |

- 記録は `.dispatch/events.jsonl` に貯まります（監視ボードは読むだけで、何も書き換えません）
- 差し戻したタスクをやり直すと、「差し戻し○回」として履歴が残ります（手順は `review.sh` の説明を参照）
- `index.html` をサーバーなしで直接開くと、デモデータで表示されます
- 動作確認用に、模擬AIの作業時間を延ばせます：`MOCK_SECS=30 tools/dispatch/dispatch.sh --mock --no-pr tasks/T00*.md`

## ふだんの使い方

1. 朝、Claude Code に「今日のタスクの指示書を `tasks/` に書いて」と頼む（テンプレートを使わせる）
2. 指示書をざっと見て、Claude Code に「dispatch.sh で配って」と頼む（自分で実行してもよい）
3. 日中は監視ボードで進み具合を見る（失敗したら「要対応」に出る）
4. 夕方、PRを Claude にレビューさせ、`review.sh` で検収OKか差し戻しを記録、問題なければマージ
5. `tools/dispatch/cleanup.sh --merged` で片付け（監視ボードで「完了」になる）

## 注意

- **自動承認は作業場所の中だけ**：各AIはタスクごとの worktree の中で動きます。`agents.conf` のフラグもその前提です
- **同じファイルを2つのタスクに触らせない**：指示書の `allowed` が重ならないようにする
- **AIの「直りました」をうのみにしない**：見た目の変更は、PRのスクリーンショットか実際の画面で確認する
- **Muse の秘書アプリと Muse Image は対象外**：コマンドから動かせないので、手で使う
- 指示書は `$(cat …)` でコマンドの引数として渡すため、極端に長い指示書（数万文字）は避ける
