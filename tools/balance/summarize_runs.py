# バランス調整用の記録（balance_logs/runs.jsonl）を、集計して表示する。
#   python tools/balance/summarize_runs.py [記録のファイル]      既定は balance_logs/runs.jsonl
# 出すもの：プレイ数・終わり方、ボスの討伐の速さ、DPS、スキルの使われ方とダメージの割合、ドロップ、最終装備のレアリティ
import json
import os
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')  # Windows のコンソールでも、日本語が文字化けしないように
from collections import Counter, defaultdict
from statistics import mean, median

here = os.path.dirname(os.path.abspath(__file__))
path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', '..', 'balance_logs', 'runs.jsonl')
runs = []
with open(path, encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if line:
            runs.append(json.loads(line))
if not runs:
    print('記録がありません:', path)
    sys.exit(0)


def stat(values, fmt='%.1f'):
    if not values:
        return '—'
    return ('平均 ' + fmt + ' / 中央 ' + fmt + ' / 最小 ' + fmt + ' / 最大 ' + fmt) % (mean(values), median(values), min(values), max(values))


print('== プレイ数: %d（自動 %d / 手動 %d）' % (len(runs), sum(r['mode'] == 'auto' for r in runs), sum(r['mode'] == 'manual' for r in runs)))
print('終わり方:', dict(Counter(r['end_reason'] for r in runs)))
print('プレイ時間(秒):', stat([r['duration_seconds'] for r in runs]))
print('最大DPS:', stat([r['max_dps'] for r in runs]))
print('平均DPS:', stat([r['avg_dps'] for r in runs]))
print('受けたダメージ:', stat([r['damage_taken'] for r in runs], '%.0f'))
print('レベル:', stat([r['player'].get('level', 0) for r in runs], '%.1f'))

bosses = [r['boss'] for r in runs if r['boss'].get('killed')]
print('\n== ボス: 倒した %d / 出会った %d' % (len(bosses), sum(r['boss'].get('seen', False) for r in runs)))
print('スタートから討伐まで(秒):', stat([b['kill_seconds'] for b in bosses]))
print('動き出してから討伐まで(秒):', stat([b['fight_seconds'] for b in bosses]))

usage = defaultdict(lambda: [0, 0, 0])
for r in runs:
    for sid, s in r['skills'].items():
        usage[sid][0] += s['casts']
        usage[sid][1] += s['chained_casts']
        usage[sid][2] += s['damage']
total_damage = sum(v[2] for v in usage.values()) or 1
print('\n== スキル（使用回数 / うちチェイン / ダメージ / 割合）')
for sid, (casts, chained, damage) in sorted(usage.items(), key=lambda kv: -kv[1][2]):
    print('  %-14s %6d %6d %9d  %5.1f%%' % (sid, casts, chained, damage, 100.0 * damage / total_damage))

rarity = Counter()
gems = Counter()
currency = 0
for r in runs:
    rarity.update(r['drops']['items_by_rarity'])
    gems.update(r['drops']['gems'])
    currency += r['drops']['currency']
print('\n== ドロップ（全プレイの合計）')
print('装備のレアリティ:', dict(rarity))
print('ジェム:', dict(gems))
print('通貨: %d（1プレイ平均 %.0f）' % (currency, currency / len(runs)))

final = Counter()
for r in runs:
    for item in r['final_equipment']:
        final[item['rarity']] += 1
print('\n== 最終装備のレアリティ:', dict(final))
loadouts = Counter(','.join(sorted(s['skill'] for s in r['start_loadout'])) for r in runs)
print('\n== スタート構成の回数:')
for k, v in loadouts.most_common():
    print('  %3d  %s' % (v, k))

# ---- 死因 ----
deaths = [r for r in runs if r['end_reason'] == 'death' and r.get('death')]
if deaths:
    print('\n== 死因（やられた %d 回）' % len(deaths))
    killers = Counter('%s:%s' % (d['death']['killer']['enemy'], d['death']['killer']['kind']) for d in deaths if d['death'].get('killer'))
    print('とどめの攻撃:', dict(killers.most_common()))
    in_boss = [d for d in deaths if d['death'].get('boss', {}).get('awake')]
    raged = [d for d in deaths if d['death'].get('boss', {}).get('raged')]
    print('ボスが動いているときにやられた: %d / 激昂後: %d / それ以外（道中）: %d' % (len(in_boss), len(raged), len(deaths) - len(in_boss)))
    print('やられた時刻(秒):', stat([d['death']['seconds'] for d in deaths]))
    ratios = [d['death']['boss']['life_ratio'] for d in in_boss]
    if ratios:
        print('そのときのボスの残り体力(割合):', stat(ratios, '%.2f'))
by_source = Counter()
for r in runs:
    for key, value in r.get('damage_taken_by', {}).items():
        by_source[key] += value
if by_source:
    print('\n== 受けたダメージの内訳（全プレイの合計）')
    total_taken = sum(by_source.values()) or 1
    for key, value in by_source.most_common():
        print('  %-22s %8.0f  %5.1f%%' % (key, value, 100.0 * value / total_taken))
print('\n回避の回数(1プレイ):', stat([r.get('dodges', 0) for r in runs], '%.0f'))

heal_used = [r.get('heals', {}).get('used', r['player'].get('heals_used', 0)) for r in runs]
print('回復を使った回数(1プレイ):', stat(heal_used, '%.1f'))
ratios = [e['life_before_ratio'] for r in runs for e in r.get('heals', {}).get('events', [])]
if ratios:
    print('回復を使う前の体力(割合):', stat(ratios, '%.2f'))
print('回復を使い切ったプレイ: %d / %d' % (sum(1 for r in runs if r.get('heals', {}).get('left', 1) == 0), len(runs)))
