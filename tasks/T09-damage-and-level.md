---
id: T09
agent: claude
title: ダメージ計算・ステータス・属性耐性・経験値とレベル
allowed: scripts/stats/ tests/test_stats.gd
---

## 目的
スキルのダメージに、装備やツリーの効果を正しく乗せる計算の土台を作る。経験値とレベルアップも入れる。
画面や操作はまだ作らない（純粋な計算だけ。テストで確かめる）。

## 前提（企画より）
- レベルアップでは、ステータスは一切上がらない。もらえるのはスキルツリーのポイント1つだけ。強さはツリー・装備・ジェムからだけ来る
- 付与効果の種類は `docs/data_schema.md` の「stat に使えるキー」と `AffixDef.STATS`
- スキルの属性は physical / fire / cold / lightning（`SkillDef.element`）

## やること
1. `scripts/stats/stat_block.gd`（class_name StatBlock）：stat のキー → 合計値。`add(key, value)`、`merge(other)`、`get_value(key)`
2. `scripts/stats/damage_calc.gd`（class_name DamageCalc）の静的関数
   - `skill_damage(skill: SkillDef, stats: StatBlock, roll: float) -> float`
     - 基本値（roll）×（1 + (damage_pct + その属性の *_damage_pct) / 100）
   - `apply_resistance(amount: float, element: String, target_res: float) -> float`
     - 耐性%ぶん減らす。耐性の上限は75%、下限は-100%。physical には耐性を使わない
   - `apply_armor(amount: float, armor: float) -> float`
     - physical だけ。減り方は `amount * amount / (amount + armor * 0.5)` を仮の式とし、定数は `scripts/stats/` 内の const にまとめる
3. `scripts/stats/level_curve.gd`（class_name LevelCurve）
   - `xp_to_next(level: int) -> int`：仮の式 `20 * level^1.5`（四捨五入）
   - `add_xp(state: Dictionary, amount: int) -> int`：`{"level", "xp", "points"}` を更新し、上がったレベル数を返す。1レベルにつき points +1
   - 最大レベル100
4. `tests/test_stats.gd`：上の式の境目（耐性75%上限、-100%下限、レベルの繰り越し、最大レベル）をテスト

## 完了の条件
- テストが全部成功
- 定数（耐性の上限など）は名前付きの const。数字をコードの途中に直接書かない

## やらないこと
- プレイヤーへの組み込み（T10 でスキル実行と一緒にやる）
- スキルツリー本体
