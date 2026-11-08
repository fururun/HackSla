#!/usr/bin/env bash
# backup.sh — HackSla のバックアップを取る（コミットのたびに自動で動く。手で動かしてもよい）
#
# 取るもの:
#   HackSla_<日時>_<コミット>.bundle   全ブランチの全履歴（コミット済みのものは、これだけで元に戻せる）
#   dispatch_<日時>.tar.gz             AIへの指示・結果のログ（.dispatch/。git に入らないもの）
#   backup.log                          いつ・何を取ったかの記録
#
# 置き場所: 既定は ~/Documents/HackSla-backups。環境変数 HACKSLA_BACKUP_DIR で変えられる
#           （別のドライブにすると、ディスクが壊れたときにも残る）
# 残す数  : 既定 30 世代。環境変数 HACKSLA_BACKUP_KEEP で変えられる。古いものは自動で消す
# 間隔    : 直前のバックアップから 120 秒以内なら取らない（連続コミットで増えすぎないように）。FORCE=1 で必ず取る
#
# 元に戻すとき:  git clone <bundleのパス> HackSla_restored
set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "gitリポジトリの中で実行してください" >&2; exit 1; }
cd "$ROOT" || exit 1
DEST="${HACKSLA_BACKUP_DIR:-$HOME/Documents/HackSla-backups}"
KEEP="${HACKSLA_BACKUP_KEEP:-30}"
MIN_GAP="${HACKSLA_BACKUP_MIN_GAP:-120}"
mkdir -p "$DEST" || exit 1

latest="$(ls -1t "$DEST"/HackSla_*.bundle 2>/dev/null | head -n 1)"
if [ -z "${FORCE:-}" ] && [ -n "$latest" ]; then
  age=$(( $(date +%s) - $(date -r "$latest" +%s) ))
  if [ "$age" -lt "$MIN_GAP" ]; then
    echo "直前のバックアップから ${age} 秒。スキップします（FORCE=1 で必ず取る）"
    exit 0
  fi
fi

ts="$(date +%Y%m%d_%H%M%S)"
sha="$(git rev-parse --short HEAD)"
bundle="$DEST/HackSla_${ts}_${sha}.bundle"
if ! git bundle create "$bundle" --all >/dev/null 2>&1; then
  echo "$(date '+%F %T') 失敗: bundle を作れませんでした" >> "$DEST/backup.log"
  exit 1
fi
note="bundle=$(basename "$bundle") $(du -k "$bundle" | cut -f1)KB"

if [ -d .dispatch ]; then
  tar czf "$DEST/dispatch_${ts}.tar.gz" .dispatch 2>/dev/null && note="$note dispatch_${ts}.tar.gz"
fi

# 古いものを消す（このフォルダの中の、バックアップのファイルだけ）
ls -1t "$DEST"/HackSla_*.bundle 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r f; do rm -f "$f"; done
ls -1t "$DEST"/dispatch_*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r f; do rm -f "$f"; done

echo "$(date '+%F %T') OK commit=$sha $note" >> "$DEST/backup.log"
echo "バックアップしました: $bundle"
