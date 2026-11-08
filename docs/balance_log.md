# バランス調整用の記録（balance_logs/runs.jsonl）

1回のプレイにつき、1行のJSON。書くのは `scripts/core/balance_log.gd`。
書くとき：やられた時、やり直しの直前（F5・自動）、ウィンドウを閉じた時。テスト・撮影（`--script`）のときは、プロジェクトには書かず、`user://logs_tools/` に書く。

| 項目 | 内容 |
| --- | --- |
| schema | 記録の形の版（いまは 1） |
| time | 書いた日時 |
| mode | `auto`（自動戦闘）／`manual`（手で遊んだ） |
| run_no | 自動の周回の何周目か |
| end_reason | `death`（やられた）／`boss_cleared`（ボスを倒して、やり直し）／`restart`（途中でやり直し）／`quit`・`exit`（閉じた） |
| duration_seconds | ゲームの中の経過秒（止まっている間は進まない） |
| player | level、max_life、heals_left（回復の残り）、heals_used |
| start_loadout / final_loadout | スキル枠ごとの `{slot, skill, support}`。スタート時と、終わり時 |
| skills | スキルidごとに `{casts（使った回数。チェインで出た技も、その技のidで数える）, chained_casts（そのうち、チェインで出た回数）, damage（与えたダメージ）}` |
| chain_casts | チェインが出た回数の合計 |
| damage_dealt / damage_taken | 与えた／受けたダメージの合計（受けた分は、防御で減らす前） |
| damage_taken_by | 受けたダメージの内訳。`敵のid:攻撃の種類` ごとの合計（攻撃の種類：melee 殴り / aoe 叩きつけ / rain 岩落とし / charge 突進 / shot 弾） |
| dodges | 回避を出した回数 |
| mana | マナの記録：max（最大）、regen（毎秒の回復）、spent（使った合計）、spent_per_second、denied_casts（マナ不足で出せなかった回数。スキルidごと）、denied_total |
| heals | 回復の使用：used（使った回数）、left（残り）、max（はじめの回数）、events（使うたびに `{t（時刻）, life_before_ratio（使う前の体力の割合）, amount（回復した量）}`） |
| death | `end_reason` が `death` のときだけ。やられた状況：seconds、killer（敵・攻撃の種類・ダメージ）、last_hits（直近8回に受けた攻撃と、その直前の体力）、position、enemies_within_80（近くの敵の数）、boss（distance・awake・raged・life_ratio） |
| avg_dps | damage_dealt ÷ プレイ時間 |
| max_dps | 最大DPS（直近5秒の平均の、最大値。右上の「最大」と同じ） |
| kills / kills_by_enemy | 倒した数。敵のidごとの数 |
| boss | seen（出会った）、life、wake_seconds（動き出した時刻）、rage_seconds（激昂した時刻）、killed、kill_seconds（スタートから討伐まで）、fight_seconds（動き出してから討伐まで） |
| final_equipment | 最後に着ていた装備。`{slot, name, base, rarity, tier, power, stats, affixes}` |
| equipment_stats | 装備の性能の合計 |
| equips / skipped_items | 着替えた回数／見送った（着替えなかった）装備の数 |
| drops | counts（item / skill_gem / support_gem / currency_piles）、currency（通貨の合計）、items_by_rarity、gems、item_list（`レアリティ\|土台\|性能`。最大300件） |
| picked_gems | 拾ったジェムの数（`skill:slash` など） |

## 見かた

- 敵の強さ・ボスの硬さ：`boss.kill_seconds`、`boss.fight_seconds`、`damage_taken`、`end_reason` の `death` の割合
- スキルの強さ：`skills` のダメージの割合。使われないスキルがないか
- 装備の出方：`drops.items_by_rarity`、`final_equipment` のレアリティ
- 集計：`python tools/balance/summarize_runs.py`
