#!/usr/bin/env bash
# cleanup.sh — 終わったタスクの作業場所とブランチを片付ける
#
# 使い方:
#   tools/dispatch/cleanup.sh T07 T12      # 指定したタスクだけ
#   tools/dispatch/cleanup.sh --merged     # 基準ブランチにマージ済みのタスクをまとめて
#
# ブランチは「マージ済み」のときだけ消します（未マージの作業は消しません）。
set -u
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "gitリポジトリの中で実行してください" >&2; exit 1; }
cd "$ROOT"
. "$KIT_DIR/agents.conf"
. "$KIT_DIR/lib.sh"
BASE="${BASE_BRANCH:-$(git symbolic-ref --short HEAD)}"
WT_ROOT="${WT_ROOT:-$(dirname "$ROOT")/$(basename "$ROOT")-worktrees}"

ids=()
if [ "${1:-}" = "--merged" ]; then
  for b in $(git branch --merged "$BASE" --format='%(refname:short)' | grep '^task/'); do ids+=("${b#task/}"); done
else
  ids=("$@")
fi
[ ${#ids[@]} -gt 0 ] || { echo "片付けるタスクがありません"; exit 0; }

for id in "${ids[@]}"; do
  wt="$WT_ROOT/$id"
  if [ -d "$wt" ]; then
    git worktree remove "$wt" && echo "  作業場所を削除: $id"
  fi
  if git branch --merged "$BASE" --format='%(refname:short)' | grep -qx "task/$id"; then
    git branch -q -d "task/$id" && echo "  ブランチを削除: task/$id" && emit closed "$id" "-"
  elif git show-ref --verify --quiet "refs/heads/task/$id"; then
    echo "  ブランチ task/$id は未マージなので残しました（不要なら git branch -D task/$id）"
  fi
done
git worktree prune
