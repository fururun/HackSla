import json, re, os
root = r'C:\Users\furur\Documents\HackSla'


def load(p):
    return json.load(open(os.path.join(root, p), encoding='utf-8'))


def dump(p, data, indent):
    text = json.dumps(data, ensure_ascii=False, indent=indent)
    text = re.sub(r'\[\s*([^\[\]{}]*?)\s*\]', lambda m: '[' + re.sub(r'\s*\n\s*', ' ', m.group(1)) + ']', text)
    open(os.path.join(root, p), 'w', encoding='utf-8', newline='\n').write(text + '\n')


new_skills = [
    {"id": "blaze_thrust", "name": "焔突き", "element": "fire", "kind": "melee", "damage": [66, 90], "cooldown": 0.5,
     "range": 60, "radius": 14, "speed": 0, "chain_only": True,
     "description": "炎をまとった一突きで、燃える敵を深く貫く。"},
    {"id": "thunder_fall", "name": "雷落とし", "element": "lightning", "kind": "area", "damage": [54, 76], "cooldown": 0.7,
     "range": 0, "radius": 58, "speed": 0, "chain_only": True,
     "description": "雷を受けた敵の足元へ、続けて雷を落とす。"},
    {"id": "magma_ball", "name": "溶岩玉", "element": "fire", "kind": "projectile", "damage": [58, 80], "cooldown": 0.5,
     "range": 230, "radius": 12, "speed": 250, "chain_only": True,
     "description": "砕けた地面から、溶けた岩の玉を撃ち出す。"},
    {"id": "steam_burst", "name": "湯気爆ぜ", "element": "cold", "kind": "area", "damage": [50, 70], "cooldown": 0.7,
     "range": 0, "radius": 64, "speed": 0, "chain_only": True,
     "description": "火で温まった敵に冷気をぶつけ、蒸気を爆ぜさせる。"},
]
new_chains = [
    {"id": "blaze_thrust", "name": "焔突き", "prev_skill": "", "next_skill": "", "prev_tags": ["fire", "area"],
     "next_tags": ["melee"], "result": "blaze_thrust",
     "description": "火の範囲スキルの次に近接スキルを使うと、燃える敵を貫く突きに変わる。"},
    {"id": "thunder_fall", "name": "雷落とし", "prev_skill": "", "next_skill": "", "prev_tags": ["lightning", "projectile"],
     "next_tags": ["area"], "result": "thunder_fall",
     "description": "雷の飛び道具の次に範囲スキルを使うと、足元へ雷を落とす技に変わる。"},
    {"id": "magma_ball", "name": "溶岩玉", "prev_skill": "", "next_skill": "", "prev_tags": ["physical", "area"],
     "next_tags": ["fire", "projectile"], "result": "magma_ball",
     "description": "物理の範囲スキルの次に火の飛び道具を使うと、溶けた岩の玉を撃ち出す技に変わる。"},
    {"id": "steam_burst", "name": "湯気爆ぜ", "prev_skill": "", "next_skill": "", "prev_tags": ["fire", "projectile"],
     "next_tags": ["cold", "area"], "result": "steam_burst",
     "description": "火の飛び道具の次に冷気の範囲スキルを使うと、蒸気を爆ぜさせる技に変わる。"},
]
names = {
    "blaze_thrust": [("焔突き", "ほむらづき", "炎をまとった一突きで、燃える敵を深く貫く。"),
                     ("火走り", "ひばしり", "燃える刃が走り、まっすぐ貫く。"),
                     ("紅蓮突き", "ぐれんづき", "紅蓮の炎を乗せた突きで、敵を貫く。")],
    "thunder_fall": [("雷落とし", "かみなりおとし", "雷を受けた敵の足元へ、続けて雷を落とす。"),
                     ("雷鳴の輪", "らいめいのわ", "雷鳴とともに、足元に光の輪が広がる。"),
                     ("稲光の庭", "いなびかりのにわ", "辺り一面が、稲光で白く染まる。")],
    "magma_ball": [("溶岩玉", "ようがんだま", "砕けた地面から、溶けた岩の玉を撃ち出す。"),
                   ("熱岩投げ", "ねつがんなげ", "熱い岩のかたまりを、まっすぐ投げつける。"),
                   ("岩火の弾", "いわびのたま", "燃える岩の弾が、敵を押し潰す。")],
    "steam_burst": [("湯気爆ぜ", "ゆげばぜ", "火で温まった敵に冷気をぶつけ、蒸気を爆ぜさせる。"),
                    ("霧ふき", "きりふき", "熱と冷気がぶつかって、白い霧を吹き出す。"),
                    ("白煙の輪", "はくえんのわ", "白い煙が輪になって、一気に広がる。")],
}

skills = load('data/skills/skills.json')
have = {s['id'] for s in skills}
skills += [s for s in new_skills if s['id'] not in have]
dump('data/skills/skills.json', skills, 2)

chains = load('data/chains/chains.json')
have = {c['id'] for c in chains}
chains += [c for c in new_chains if c['id'] not in have]
dump('data/chains/chains.json', chains, 2)

n = load('data/text/names.json')
have = {(e['category'], e['id']) for e in n['entries']}
for sid, plans in names.items():
    if ('skill', sid) in have:
        continue
    n['entries'].append({"category": "skill", "id": sid, "adopted": 1,
                         "candidates": [{"plan": i + 1, "display_name": a, "reading": b, "description": c} for i, (a, b, c) in enumerate(plans)]})
json.dump(n, open(os.path.join(root, 'data/text/names.json'), 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=1)
open(os.path.join(root, 'data/text/names.json'), 'a', encoding='utf-8', newline='\n').write('\n')
print('skills', len(skills), 'chains', len(chains))
