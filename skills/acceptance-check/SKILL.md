---
name: acceptance-check
description: 検収の確認項目。Claude社の検収担当がマージを判断するときに使う
---

# 検収の確認項目

1. 変更されたファイルが `allowed` の中だけか（`git diff --stat main...task/<ID>`）
2. テストが全部成功するか（自分で実行）
3. メイン画面がエラーなく動くか（`--quit-after 300`）
4. 指示書の「完了の条件」を1つずつ満たしているか
5. AGENTS.md のルール（型付き、数値は data/、敵に物理演算なし、プール化）
6. `docs/concept.md` の「やらないこと」に反していないか
7. 見た目が変わるなら画面を撮って確かめる
8. 相互チェックの結果を読む（NGの指摘が正しいか確かめる）
9. マージなら `review.sh <ID> ok`、差し戻しなら `review.sh <ID> ng "理由"`
