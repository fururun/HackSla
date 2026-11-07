#!/usr/bin/env bash
# review.sh — 納品物を検収する（監視ボードに記録される）
#
# 使い方:
#   tools/dispatch/review.sh T08 ok                       # 検収OK（マージ待ち）
#   tools/dispatch/review.sh T08 ng "敵が壁をすり抜ける"   # 差し戻し（理由を残す）
#
# 差し戻したタスクをやり直させるとき:
#   1. 指示書（tasks/T08.md）に直してほしい点を書き足す
#   2. tools/dispatch/cleanup.sh T08 && git branch -D task/T08
#   3. tools/dispatch/dispatch.sh tasks/T08.md
#   監視ボードでは「差し戻し○回」として履歴が残ります。
#
# マージ済みのタスクは、cleanup.sh --merged を実行すると「完了」になります。
set -u
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "gitリポジトリの中で実行してください" >&2; exit 1; }
. "$KIT_DIR/lib.sh"

id="${1:-}"; verdict="${2:-}"; note="${3:-}"
[ -n "$id" ] && [ -n "$verdict" ] || { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

case "$verdict" in
  ok|OK)  emit accepted "$id" "-" note="$note"; echo "$id を検収OKにしました" ;;
  ng|NG)  [ -n "$note" ] || { echo "差し戻しの理由を書いてください（例: review.sh $id ng \"理由\"）" >&2; exit 1; }
          emit rejected "$id" "-" note="$note"; echo "$id を差し戻しにしました: $note" ;;
  *)      echo "2つ目は ok か ng にしてください" >&2; exit 1 ;;
esac
