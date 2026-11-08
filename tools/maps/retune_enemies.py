# 敵の強さを一度に調整する（2026-11-08：簡単すぎるという声を受けて）。  python tools/maps/retune_enemies.py
# data/enemies/enemies.json の、決まった敵の数字だけを書き換える。ほかの項目は、そのまま。
import json, os

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'data', 'enemies', 'enemies.json')
with open(path, encoding='utf-8') as f:
    enemies = json.load(f)

changes = {
    'swarmling': {'life': 30, 'speed': 64, 'damage': 6, 'xp': 4, 'pack': [10, 16]},
    'brute': {'life': 520, 'speed': 34, 'damage': 20, 'xp': 26},
    'rock_lord': {'life': 9000, 'damage': 32, 'xp': 220,
                  'aoe_radius': 70, 'aoe_damage': 40, 'aoe_interval': 4.5, 'aoe_windup': 1.2,
                  'rage_below': 0.5, 'rage_speed_mult': 1.5, 'rage_interval_mult': 0.45,
                  'rain_radius': 36, 'rain_damage': 28, 'rain_interval': 3.0, 'rain_windup': 1.0, 'rain_count': 4},
}
for e in enemies:
    for k, v in changes.get(e['id'], {}).items():
        e[k] = v

text = json.dumps(enemies, ensure_ascii=False, indent=2)
# pack のような短い配列は1行に戻す
import re
text = re.sub(r'\[\s*(\d+),\s*(\d+)\s*\]', r'[\1, \2]', text)
with open(path, 'w', encoding='utf-8', newline='\n') as f:
    f.write(text + '\n')
print('ok')
for e in enemies:
    print(e['id'], {k: e[k] for k in ('life', 'speed', 'damage', 'xp', 'pack') if k in e}, {k: e[k] for k in e if k.startswith('aoe_')})
