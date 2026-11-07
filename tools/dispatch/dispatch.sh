#!/usr/bin/env bash
# =============================================================
# dispatch.sh — タスク指示書を各AIに一斉に配って、同時に作業させる
#
# 使い方:
#   tools/dispatch/dispatch.sh [オプション] tasks/T07.md tasks/T12.md ...
#
# オプション:
#   --dry-run   何も実行せず、誰に何を渡すかだけ表示する
#   --mock      本物のAIの代わりに模擬AIを動かす（仕組みのテスト用）
#   --no-pr     コミットまでで止め、push と PR 作成をしない
#   -h, --help  この説明を表示する
#
# 流れ（1タスクごと）:
#   1. task/<ID> ブランチと作業場所（git worktree）を作る
#   2. 共通ルール＋指示書の本文をプロンプトにして、担当AIをヘッドレスで起動
#      （全タスクを同時に起動し、全員が終わるまで待つ）
#   3. 変更があればコミット → push → PR作成（--no-pr なら commit まで）
#   4. 最後に結果の一覧を表示。ログは .dispatch/logs/ に残る
#
# macOS標準の bash 3.2 でも動くように書いています。
# =============================================================
set -u

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"

DRY_RUN=0
MOCK=0
NO_PR=0
TASK_FILES=()

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "エラー: $*" >&2; exit 1; }

# ---------- 引数 ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --mock)    MOCK=1 ;;
    --no-pr)   NO_PR=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)        die "知らないオプションです: $1" ;;
    *)         TASK_FILES+=("$1") ;;
  esac
  shift
done
[ ${#TASK_FILES[@]} -gt 0 ] || { usage; exit 1; }

# ---------- 準備 ----------
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "gitリポジトリの中で実行してください"
cd "$ROOT"

[ -f "$KIT_DIR/agents.conf" ] || die "$KIT_DIR/agents.conf がありません"
# shellcheck source=agents.conf
. "$KIT_DIR/agents.conf"
# shellcheck source=lib.sh
. "$KIT_DIR/lib.sh"
# PCごとの設定（Godot の場所など）。Git には入れない
[ -f "$KIT_DIR/agents.local.conf" ] && . "$KIT_DIR/agents.local.conf"

BASE="${BASE_BRANCH:-$(git symbolic-ref --short HEAD 2>/dev/null)}"
[ -n "$BASE" ] || die "基準ブランチがわかりません（BASE_BRANCH を agents.conf で指定してください）"
WT_ROOT="${WT_ROOT:-$(dirname "$ROOT")/$(basename "$ROOT")-worktrees}"
LOG_DIR="$ROOT/.dispatch/logs"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"

if [ "$DRY_RUN" -eq 0 ] && [ -n "$(git status --porcelain --untracked-files=no)" ]; then
  echo "注意: 基準ブランチ（$BASE）に未コミットの変更があります。各AIはコミット済みの状態から作業します。" >&2
fi

# ---------- 指示書の読み取り ----------
# 先頭の --- と --- の間にある「キー: 値」を読む
fm_get() {
  awk -v k="$2" '
    NR==1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    { i = index($0, ":"); if (i > 0 && substr($0, 1, i-1) == k) { v = substr($0, i+1); sub(/^[ \t]+/, "", v); sub(/[ \t\r]+$/, "", v); print v; exit } }
  ' "$1"
}
# 2つ目の --- より後ろ（本文）を出す。--- が無ければ全文
fm_body() {
  awk '
    NR==1 { if ($0 == "---") { fm = 1; next } else { body = 1 } }
    fm && $0 == "---" { fm = 0; body = 1; next }
    body { print }
  ' "$1"
}

## 役割を省略したときの既定
default_role() {
  case "$1" in claude) echo design ;; codex) echo impl ;; gemini) echo balance ;; *) echo "" ;; esac
}

agent_cmd() {
  case "$1" in
    claude) echo "${CLAUDE_CMD:-}" ;;
    codex)  echo "${CODEX_CMD:-}" ;;
    gemini) echo "${GEMINI_CMD:-}" ;;
    muse)   echo "${MUSE_CMD:-}" ;;
    *)      echo "" ;;
  esac
}

# ---------- 1. 指示書を確認して作業場所を作る（順番に） ----------
IDS=()
echo "== 配布の準備（基準: $BASE / 実行ID: $RUN_ID） =="
for f in "${TASK_FILES[@]}"; do
  [ -f "$f" ] || { echo "  ✗ $f: ファイルがありません" >&2; continue; }
  id="$(fm_get "$f" id)"
  agent="$(fm_get "$f" agent | tr 'A-Z' 'a-z')"
  title="$(fm_get "$f" title)"
  allowed="$(fm_get "$f" allowed)"
  role="$(fm_get "$f" role)"
  [ -n "$role" ] || role="$(default_role "$agent")"

  [ -n "$id" ]    || { echo "  ✗ $f: id がありません" >&2; continue; }
  [ -n "$agent" ] || { echo "  ✗ $f: agent がありません" >&2; continue; }
  case "$agent" in claude|codex|gemini|muse) ;; *) echo "  ✗ $id: agent は claude / codex / gemini / muse のどれかにしてください（今: $agent）" >&2; continue ;; esac
  if [ "$MOCK" -eq 0 ]; then
    acmd="$(agent_cmd "$agent")"
    if [ -z "$acmd" ]; then
      echo "  ✗ $id: agents.conf に $agent のコマンドがありません" >&2; continue
    fi
    exe="$(echo "$acmd" | awk '{print $1}')"
    if ! command -v "$exe" >/dev/null 2>&1; then
      echo "  ✗ $id: 「$exe」コマンドが見つかりません（$agent のCLIが入っていないか、PATHが通っていません）" >&2; continue
    fi
  fi

  branch="task/$id"
  wt="$WT_ROOT/$id"
  role_file="$ROOT/agents/$agent/$role.md"
  if [ -n "$role" ] && [ ! -f "$role_file" ]; then
    echo "  ✗ $id: 役割「$role」の心得（agents/$agent/$role.md）がありません" >&2; continue
  fi
  echo "  • $id → $agent／${role:-役割なし}「$title」（触ってよい場所: ${allowed:-指定なし}）"

  if [ "$DRY_RUN" -eq 1 ]; then IDS+=("$id"); continue; fi

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "    ✗ ブランチ $branch が既にあります。前回分を片付けてから再実行してください" >&2; continue
  fi
  mkdir -p "$WT_ROOT"
  if ! git worktree add -q -b "$branch" "$wt" "$BASE" 2>"$LOG_DIR/$id.worktree.err"; then
    echo "    ✗ 作業場所を作れませんでした（$LOG_DIR/$id.worktree.err）" >&2; continue
  fi

  # プロンプト = 共通ルール + 指示書の本文
  prompt="$LOG_DIR/$id.prompt.md"
  {
    echo "あなたはこのゲーム開発チームの一員です（担当: $agent）。次のルールを必ず守ってください。"
    echo "- まずリポジトリ直下の AGENTS.md を読み、その規約に従うこと"
    echo "- Godot の実行ファイルは「${GODOT_BIN:-godot}」（AGENTS.md の確認手順の godot をこれに置き換える）"
    echo "- 変更してよいのは次の場所だけ: ${allowed:-指示書に書かれた場所}"
    echo "- git の commit / push / PR作成はしないこと（配布スクリプトが行います）"
    echo "- 作業の最後に「やったこと」「確認方法」「気になる点」を短くまとめて出力すること"
    echo
    if [ -f "$role_file" ]; then
      echo "## あなたの役割"
      echo
      cat "$role_file"
      echo
    fi
    echo "## タスク $id: $title"
    echo
    fm_body "$f"
  } > "$prompt"

  # 実行時に使う情報を保存
  printf '%s\n%s\n%s\n%s\n' "$agent" "$title" "$wt" "$branch" > "$LOG_DIR/$id.meta"
  emit ordered "$id" "$agent" role="$role" title="$title" allowed="$allowed" run="$RUN_ID" file="$f" branch="$branch" mock="$MOCK"
  IDS+=("$id")
done

[ ${#IDS[@]} -gt 0 ] || die "配れるタスクがありませんでした"
if [ "$DRY_RUN" -eq 1 ]; then echo "== --dry-run なので、ここで終わります =="; exit 0; fi

# ---------- 2〜3. 全員を同時に起動 ----------
run_task() {
  id="$1"
  agent="$(sed -n 1p "$LOG_DIR/$id.meta")"
  title="$(sed -n 2p "$LOG_DIR/$id.meta")"
  wt="$(sed -n 3p "$LOG_DIR/$id.meta")"
  branch="$(sed -n 4p "$LOG_DIR/$id.meta")"
  log="$LOG_DIR/$id.log"
  PROMPT_FILE="$LOG_DIR/$id.prompt.md"
  GODOT="${GODOT_BIN:-godot}"
  export PROMPT_FILE GODOT

  if [ "$MOCK" -eq 1 ]; then
    cmd="\"$KIT_DIR/mock/agent.sh\" $agent"
  else
    cmd="$(agent_cmd "$agent")"
  fi

  # 指示書はファイルで渡す（複数行の日本語を引数にすると、Windowsでは途中で切れるため）
  cp "$PROMPT_FILE" "$wt/.dispatch_task.md"
  TASK_LINE="${TASK_LINE:-Read the file .dispatch_task.md in the current directory and follow its instructions exactly.}"
  export TASK_LINE

  start=$(date +%s)
  emit started "$id" "$agent" run="$RUN_ID"
  if command -v timeout >/dev/null 2>&1; then
    ( cd "$wt" && timeout "${TASK_TIMEOUT:-1800}" bash -c "$cmd" ) > "$log" 2>&1 < /dev/null
  else
    ( cd "$wt" && eval "$cmd" ) > "$log" 2>&1 < /dev/null
  fi
  rc=$?
  [ "$rc" -eq 124 ] && echo "[dispatch] 制限時間（${TASK_TIMEOUT:-1800}秒）を超えたので止めました" >> "$log"
  rm -f "$wt/.dispatch_task.md"
  secs=$(( $(date +%s) - start ))

  changed="なし"; pr="-"
  # AIが自分でコミットしてしまった場合も拾う
  ahead=$(git -C "$wt" rev-list --count "$BASE..HEAD" 2>/dev/null || echo 0)
  if [ -n "$(git -C "$wt" status --porcelain)" ]; then
    git -C "$wt" add -A
    git -C "$wt" commit -q -m "$id: $title" -m "担当: $agent（dispatch $RUN_ID）" >> "$log" 2>&1
    ahead=$(git -C "$wt" rev-list --count "$BASE..HEAD")
  fi
  if [ "$ahead" -gt 0 ]; then
    changed="$(git -C "$wt" diff --shortstat "$BASE..HEAD" | sed 's/^ *//')"
    if [ "$rc" -ne 0 ]; then
      pr="AIが失敗したのでPRなし（変更はブランチに保存）"
    elif [ "$NO_PR" -eq 0 ]; then
      if git -C "$wt" push -q -u origin "$branch" >> "$log" 2>&1; then
        body="$LOG_DIR/$id.pr.md"
        {
          echo "担当: $agent / 実行ID: $RUN_ID / 終了コード: $rc / 所要: ${secs}秒"
          echo
          echo "### AIの出力（最後の40行）"
          echo '```'
          tail -n 40 "$log"
          echo '```'
        } > "$body"
        pr="$(cd "$wt" && gh pr create --base "$BASE" --head "$branch" --title "$id: $title" --body-file "$body" 2>>"$log" | tail -n 1)"
        [ -n "$pr" ] || pr="PR作成に失敗（ログ参照）"
      else
        pr="push失敗（ログ参照）"
      fi
    else
      pr="--no-pr"
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$agent" "$rc" "${secs}秒" "$changed" "$pr" > "$LOG_DIR/$id.status"
  emit finished "$id" "$agent" run="$RUN_ID" rc="$rc" secs="$secs" changed="$changed" pr="$pr"
}

echo "== ${#IDS[@]}件を同時に実行中（ログ: .dispatch/logs/<ID>.log） =="
PIDS=()
for id in "${IDS[@]}"; do
  rm -f "$LOG_DIR/$id.status"
  run_task "$id" &
  PIDS+=($!)
  echo "  ▶ $id を起動"
done
for p in "${PIDS[@]}"; do wait "$p"; done

# ---------- 4. 結果 ----------
echo
echo "== 結果 =="
echo "  ID     担当    終了  所要    変更 / PR"
fail=0
for id in "${IDS[@]}"; do
  if [ -f "$LOG_DIR/$id.status" ]; then
    IFS="$(printf '\t')" read -r sid sagent src ssecs schanged spr < "$LOG_DIR/$id.status"
    if [ "$src" != "0" ]; then mark="✗"; fail=1
    elif [ "$schanged" = "なし" ]; then mark="△"
    else mark="✓"; fi
    printf '%s %-6s %-7s %-5s %-7s %s / %s\n' "$mark" "$sid" "$sagent" "$src" "$ssecs" "$schanged" "$spr"
  else
    echo "✗ $id: 結果がありません（ログを確認してください）"; fail=1
  fi
done
echo
echo "✓=成功  △=変更なし  ✗=失敗。片付け: tools/dispatch/cleanup.sh <ID>"
exit $fail
