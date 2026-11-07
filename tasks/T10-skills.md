---
id: T10
agent: codex
role: impl
title: スキルの実行（3スキル・補助ジェム・スキルチェイン）
allowed: scripts/skills/ scripts/combat/ scripts/player/player.gd scripts/ui/ tests/test_skills.gd
---

## 目的
プロトタイプの3スキルを使えるようにし、補助ジェムとスキルチェイン（砕氷）が効くことを確かめられるようにする。

## 前提（企画より）
- スキル：斬撃（近接）、氷華（冷気の範囲）、火球（飛び道具）。数値は `DataDB.skill(id)`
- 操作：スキル枠1＝左クリック、2＝右クリック、3＝Q（`scripts/core/input_setup.gd` の skill_1〜3）。マウスの方向へ出す
- プロトタイプの初期配置：枠1 斬撃、枠2 氷華、枠3 火球＋補助「拡散」。全部のスキルに「撃破時爆発」は付けない（付け外しは T11 の画面で）
- スキルチェイン：氷華のあとに近接（斬撃）を使うと砕氷に変わる。判定は `ChainTracker`（`scripts/skills/chain_tracker.gd`）。受付時間なし、直前の1スキルだけ、2段階まで
- ダメージは `DamageCalc`（`scripts/stats/`）。当たり判定は `enemies` グループの `take_hit(amount, skill)`、距離は `Iso`
- 補助ジェムの効果は `SupportDef.modifiers`（`docs/data_schema.md`）

## やること
1. `scripts/skills/skill_slot.gd`：スキルと補助ジェム（最大1つ）の組、再使用時間
2. `scripts/skills/skill_caster.gd`：スキルを出す処理。チェインの変化（ChainTracker）→補助の効果→ダメージ→当たり判定
   - 近接：扇形（今の `player.gd` の斬撃を移す）
   - 範囲：足元の円（地面の円）
   - 飛び道具：まっすぐ飛ぶ弾。使い回す（`skills/pooling/`）。「拡散」で3方向
   - 撃破時爆発：倒した敵の位置で範囲ダメージ（`explode_damage_ratio`）
3. `scripts/player/player.gd` をスキル枠3つで動くように直す
4. 仮の見た目：範囲は地面の円、弾は小さな丸、チェインが出たら技の名前を一瞬表示（`scripts/combat/` か `scripts/ui/`）
5. 画面下にスキル枠3つと再使用時間を小さく表示（`scripts/ui/`）
6. `tests/test_skills.gd`：3スキルが案山子に当たる、氷華→斬撃で砕氷、拡散で弾が3つ、再使用時間

## 完了の条件
- テストが全部成功、メイン画面が5秒エラーなく動く
- 画面を撮って、スキル枠の表示と斬撃中の様子を確かめる

## やらないこと
- 敵の動き・プレイヤーのライフ（T08 が担当）
- スキル装備画面（T11）、ドロップ（T15）
