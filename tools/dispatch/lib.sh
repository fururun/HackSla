# lib.sh — 配布キットの共通関数（ほかのスクリプトから読み込む）
#
# emit: 取引の記録を .dispatch/events.jsonl に1行追加する。監視ボードはこれを読む。
#   emit <出来事> <タスクID> <担当> [キー=値 ...]
#   出来事: ordered（発注）/ started（着手）/ finished（納品・失敗）/
#           accepted（検収OK）/ rejected（差し戻し）/ closed（完了・片付け）

_json_str() {
  printf '%s' "$1" | tr '\r\n\t' '   ' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

emit() {
  _ev="$1"; _id="$2"; _agent="$3"; shift 3
  _line="{\"ts\":$(date +%s),\"t\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"event\":\"$_ev\",\"id\":\"$(_json_str "$_id")\",\"agent\":\"$(_json_str "$_agent")\""
  while [ $# -gt 0 ]; do
    _k="${1%%=*}"; _v="${1#*=}"
    _line="$_line,\"$_k\":\"$(_json_str "$_v")\""
    shift
  done
  mkdir -p "$ROOT/.dispatch"
  printf '%s}\n' "$_line" >> "$ROOT/.dispatch/events.jsonl"
}
