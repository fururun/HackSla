#!/usr/bin/env bash
# 模擬AI（--mock のときに本物のAIの代わりに動く）
# 仕組みのテスト用。プロンプトを読み、少しずつ途中経過を出しながら docs/smoke/<担当>.md を書いて終わる。
#   MOCK_SECS=20 … 作業時間の上限（秒）。監視ボードで「作業中」を眺めたいときに長くする
#   指示書の本文に MOCK_FAIL と書くと、わざと失敗する（エラー処理のテスト用）
agent="${1:-unknown}"
echo "[mock:$agent] 発注書を受け取りました: $PROMPT_FILE"
head -n 3 "$PROMPT_FILE" | sed "s/^/[mock:$agent] > /"

max="${MOCK_SECS:-3}"
total=$(( (RANDOM % max) + 1 ))
steps="AGENTS.mdを読んでいます|指示書の仕様を確認しています|ファイルを作成しています|動作を確認しています"
i=0
while [ $i -lt "$total" ]; do
  n=$(( i * 4 / total + 1 ))
  echo "[mock:$agent] $(echo "$steps" | cut -d'|' -f$n)…（$((i + 1))/${total}秒）"
  sleep 1
  i=$((i + 1))
done

if grep -q 'MOCK_FAIL' "$PROMPT_FILE"; then
  echo "[mock:$agent] エラー: わざと失敗します" >&2
  exit 3
fi

mkdir -p docs/smoke
{
  echo "# スモークテスト（$agent・模擬）"
  echo
  echo "- 実行日時: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- 作業場所: $(pwd)"
  echo "- 受け取ったタスク: $(grep -m1 '^## タスク' "$PROMPT_FILE" | sed 's/^## //')"
} > "docs/smoke/$agent.md"

echo "[mock:$agent] やったこと: docs/smoke/$agent.md を作成"
echo "[mock:$agent] 確認方法: ファイルを開く"
echo "[mock:$agent] 気になる点: なし"
