# HackSla

2Dドット絵・斜め見下ろし視点のハクスラ。自分で組んだビルドで、大量の敵を一気に倒す爽快感を目指します。
Claude・Codex・Gemini・Muse の4つのAIで並行して作っています。

- 企画の要点：[docs/concept.md](docs/concept.md)
- いま作っているもの：[docs/prototype.md](docs/prototype.md)
- AI共通のルール：[AGENTS.md](AGENTS.md)

## 遊び方（プロトタイプ）

1. [Godot 4.7](https://godotengine.org/download) を入れる
2. Godot でこのフォルダの `project.godot` を開き、F5 で実行

| 操作 | 内容 |
| --- | --- |
| WASD | 移動（8方向） |
| 左クリック | 斬撃（マウスの方向） |

## 開発の進め方

1. Claude が指示書を `tasks/` に書く
2. 配布スクリプトで各AIに一斉に配る：`tools/dispatch/dispatch.sh tasks/T06.md tasks/T12.md ...`
3. 監視ボードで進み具合を見る：`python3 tools/dispatch/monitor/monitor.py` → http://localhost:8765
4. 届いたPRを Claude がレビューし、`tools/dispatch/review.sh` で検収

詳しくは [tools/dispatch/README.md](tools/dispatch/README.md)。

## 確認

```sh
godot --headless --script res://tests/run_tests.gd   # テスト
godot --script res://tools/capture/capture.gd -- --out=shots/now.png   # 画面の撮影
```
