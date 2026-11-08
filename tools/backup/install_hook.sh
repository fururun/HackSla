#!/usr/bin/env bash
# install_hook.sh — コミットのたびに、自動でバックアップを取るようにする（.git/hooks/post-commit を作る）
#   tools/backup/install_hook.sh            入れる
#   tools/backup/install_hook.sh --remove   外す
# フックは git に入らないので、別のPCで使うときは、そのPCでもう一度実行する。
set -eu
ROOT="$(git rev-parse --show-toplevel)"
HOOK="$ROOT/.git/hooks/post-commit"
if [ "${1:-}" = "--remove" ]; then
  rm -f "$HOOK"
  echo "外しました: $HOOK"
  exit 0
fi
mkdir -p "$ROOT/.git/hooks"
# フックの中身は、文字化けしないよう英数字だけで書く（日本語の説明は、このファイルの上と docs/backup_and_logs.md にある）
cat > "$HOOK" <<'EOF'
#!/bin/sh
# HackSla: run tools/backup/backup.sh in the background after every commit (never blocks the commit)
ROOT="$(git rev-parse --show-toplevel)"
( "$ROOT/tools/backup/backup.sh" >/dev/null 2>&1 & )
exit 0
EOF
chmod +x "$HOOK" "$ROOT/tools/backup/backup.sh"
echo "入れました: $HOOK（コミットのたびに tools/backup/backup.sh が動きます）"
