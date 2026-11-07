#!/usr/bin/env bash
# =============================================================
# crossreview.sh — 納品されたタスクを、書いたAIとは別のAIに確認させる（相互チェック）
#
# 使い方:
#   tools/dispatch/crossreview.sh T06:gemini T14:gemini T09:codex
#   （<タスクID>:<確認するAI>。複数を同時に確認させる）
#
# オプション:
#   --mock   本物のAIの代わりに模擬AIで動かす（仕組みのテスト用）
#
# 確認するAIは、task/<ID> ブランチを読むだけ（ファイルは変更しない）。
# 結果は .dispatch/logs/<ID>.review.md に残り、監視ボードの取引履歴にも出る。
# 最終的なマージの判断は Claude（PM）が行う。
# =============================================================
set -u
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "gitリポジトリの中で実行してください" >&2; exit 1; }
cd "$ROOT"
. "$KIT_DIR/agents.conf"
. "$KIT_DIR/lib.sh"
[ -f "$KIT_DIR/agents.local.conf" ] && . "$KIT_DIR/agents.local.conf"

MOCK=0
PAIRS=()
for a in "$@"; do
  case "$a" in
    --mock) MOCK=1 ;;
    *:*) PAIRS+=("$a") ;;
    *) echo "「$a」は <タスクID>:<AI> の形で書いてください" >&2; exit 1 ;;
  esac
done
[ ${#PAIRS[@]} -gt 0 ] || { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

BASE="${BASE_BRANCH:-$(git symbolic-ref --short HEAD)}"
WT_ROOT="${WT_ROOT:-$(dirname "$ROOT")/$(basename "$ROOT")-worktrees}"
LOG_DIR="$ROOT/.dispatch/logs"
mkdir -p "$LOG_DIR" "$WT_ROOT"
git fetch -q origin 2>/dev/null

agent_cmd() {
  case "$1" in
    claude) echo "${CLAUDE_CMD:-}" ;; codex) echo "${CODEX_CMD:-}" ;;
    gemini) echo "${GEMINI_CMD:-}" ;; *) echo "" ;;
  esac
}

review_one() {
  id="$1"; reviewer="$2"
  wt="$WT_ROOT/review-$id"
  log="$LOG_DIR/$id.review.log"
  out="$LOG_DIR/$id.review.md"
  ref="task/$id"
  git show-ref --verify --quiet "refs/heads/$ref" || ref="origin/task/$id"
  if ! git rev-parse --verify --quiet "$ref" >/dev/null; then
    echo "✗ $id: ブランチ task/$id がありません" >&2; return 1
  fi
  task_file="$(grep -l "^id: $id\$" tasks/*.md 2>/dev/null | head -1)"
  author="$(sed -n 's/^agent: *//p' "$task_file" 2>/dev/null)"
  if [ "$author" = "$reviewer" ]; then
    echo "✗ $id: 書いたAI（$author）に自分の確認はさせません" >&2; return 1
  fi
  allowed="$(sed -n 's/^allowed: *//p' "$task_file" 2>/dev/null)"

  git worktree remove --force "$wt" >/dev/null 2>&1
  git worktree add -q --detach "$wt" "$ref" || { echo "✗ $id: 作業場所を作れません" >&2; return 1; }

  {
    echo "あなたはこのゲーム開発チームのQA担当です（担当: $reviewer）。ほかのAI（$author）が納品した作業を確認してください。"
    echo "- ファイルは一切変更しないこと。git の操作もしないこと（読む・テストを実行するだけ）"
    echo "- まずリポジトリ直下の AGENTS.md と docs/concept.md を読むこと"
    echo "- Godot の実行ファイルは「${GODOT_BIN:-godot}」"
    echo
    echo "## 確認すること"
    echo "1. テストが全部成功するか：\`${GODOT_BIN:-godot} --headless --import\` のあと \`${GODOT_BIN:-godot} --headless --script res://tests/run_tests.gd\`"
    echo "2. メイン画面がエラーなく動くか：\`${GODOT_BIN:-godot} --headless --quit-after 300\`"
    echo "3. 変更してよい場所（$allowed）の外を変更していないか。変更されたファイルの一覧："
    echo '```'
    git diff --stat "$BASE...$ref"
    echo '```'
    echo "4. 下の指示書の「やること」と「完了の条件」を満たしているか"
    echo "5. AGENTS.md のルール（型付きGDScript、数値は data/ に置く、敵に物理演算を使わない など）と、docs/concept.md の「やらないこと」に反していないか"
    echo
    echo "## 結果の書き方"
    echo "作業場所の直下に \`.dispatch_review.md\` を作り、1行目に「判定: OK」か「判定: NG」だけを書く。"
    echo "2行目以降に、確認したこと（実行したコマンドと結果）と、問題点（ファイル名と理由）を短く書く。"
    echo
    echo "## 確認する指示書（$id）"
    echo
    awk 'NR==1 { if ($0 == "---") { fm = 1; next } else { body = 1 } } fm && $0 == "---" { fm = 0; body = 1; next } body { print }' "$task_file"
  } > "$wt/.dispatch_task.md"
  cp "$wt/.dispatch_task.md" "$LOG_DIR/$id.review.prompt.md"

  if [ "$MOCK" -eq 1 ]; then
    cmd="printf '判定: OK\n（模擬）テスト成功、範囲内の変更のみ\n' > .dispatch_review.md; echo '[mock:$reviewer] 確認しました'"
  else
    cmd="$(agent_cmd "$reviewer")"
    [ -n "$cmd" ] || { echo "✗ $id: $reviewer のコマンドがありません" >&2; return 1; }
  fi
  export TASK_LINE GODOT="${GODOT_BIN:-godot}"
  emit review_started "$id" "$reviewer" author="$author"
  start=$(date +%s)
  if command -v timeout >/dev/null 2>&1; then
    ( cd "$wt" && timeout "${TASK_TIMEOUT:-1800}" bash -c "$cmd" ) > "$log" 2>&1 < /dev/null
  else
    ( cd "$wt" && eval "$cmd" ) > "$log" 2>&1 < /dev/null
  fi
  rc=$?
  secs=$(( $(date +%s) - start ))

  verdict="不明"
  if [ -f "$wt/.dispatch_review.md" ]; then
    cp "$wt/.dispatch_review.md" "$out"
    first="$(head -1 "$out")"
    case "$first" in *OK*) verdict="OK" ;; *NG*) verdict="NG" ;; esac
    note="$(sed -n '2,6p' "$out" | tr '\n' ' ' | cut -c1-160)"
  else
    note="結果のファイルがありません（終了コード $rc）"
  fi
  # 確認するAIがファイルを変えていないか
  changed="$(git -C "$wt" status --porcelain | grep -v '\.dispatch_' | grep -v '\.godot/' | head -5)"
  [ -n "$changed" ] && note="【注意：確認役がファイルを変更】$note"
  emit reviewed "$id" "$reviewer" verdict="$verdict" note="$note" secs="$secs" rc="$rc"
  git worktree remove --force "$wt" >/dev/null 2>&1
  printf '%s\t%s\t%s\t%s秒\t%s\n' "$id" "$reviewer" "$verdict" "$secs" "$note" > "$LOG_DIR/$id.review.status"
}

echo "== 相互チェック（${#PAIRS[@]}件を同時に）=="
PIDS=()
for p in "${PAIRS[@]}"; do
  review_one "${p%%:*}" "${p##*:}" &
  PIDS+=($!)
  echo "  ▶ ${p%%:*} を ${p##*:} が確認"
done
for pid in "${PIDS[@]}"; do wait "$pid"; done

echo
echo "== 結果 =="
for p in "${PAIRS[@]}"; do
  f="$LOG_DIR/${p%%:*}.review.status"
  if [ -f "$f" ]; then
    IFS="$(printf '\t')" read -r rid rwho rverdict rsecs rnote < "$f"
    printf '%s %-6s %-7s %-4s %s\n' "$([ "$rverdict" = OK ] && echo ✓ || echo ✗)" "$rid" "$rwho" "$rverdict" "$rnote"
    rm -f "$f"
  else
    echo "✗ ${p%%:*}: 結果なし"
  fi
done
echo "詳しい結果: .dispatch/logs/<ID>.review.md"
