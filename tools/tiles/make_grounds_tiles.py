"""廃寺の境内（屋外）の、床と壁のタイルを作る（継ぎ目のない32×16の菱形）。
出力: art/tiles/grounds_tiles.png（128×256。crypt_tiles.png と同じ並び）
  列0・1=床（ほぼ同じ色の2枚）、列2=奥の壁（木、高い）、列3=手前の壁（茂み、低い）。
  行0〜3=草（まだら）、行4=花の草、行5=土、行6=石畳、行7=草と土の混ざり
色は参考画像から：落ち着いたオリーブ寄りの緑と土色。キャラやスライムより床の彩度を抑える。
実行: python tools/tiles/make_grounds_tiles.py
"""
import math
import random
from PIL import Image

W = 32
VARIANTS = 8


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


GRASS = [hx('#4a7f33'), hx('#58903a'), hx('#68a040'), hx('#7db44c')]  # 暗い→明るい
GRASS_DARK = hx('#3b6a2d')
DIRT = [hx('#8f6d42'), hx('#a07c4c'), hx('#b38f5a'), hx('#7a5a36')]
STONE = [hx('#7d8279'), hx('#8f948a'), hx('#a1a69b')]
MORTAR = hx('#565b52')
WHITE = hx('#f1efdc')
YELLOW = hx('#e6bf3c')
PINK = hx('#d9708a')


def shade_color(c, k):
    return (min(255, int(c[0] * k)), min(255, int(c[1] * k)), min(255, int(c[2] * k)), 255)


def diamond_cells():
    cells = []
    for y in range(16):
        for x in range(W):
            px = (x + 0.5) / W * 2 - 1
            py = (y + 0.5) / 16 * 2 - 1
            if abs(px) + abs(py) <= 1.0:
                cells.append((x, y))
    return cells


CELLS = diamond_cells()


def blotch_map(rng, n, palette_len, spread):
    """ランダムな点からの最近傍で、不規則なまだら模様の色番号を決める"""
    seeds = [(rng.uniform(0, W), rng.uniform(0, 16), rng.randint(0, palette_len - 1)) for _ in range(n)]
    out = {}
    for (x, y) in CELLS:
        best = min(seeds, key=lambda s: (s[0] - x) ** 2 + ((s[1] - y) * 2) ** 2)
        out[(x, y)] = best[2]
    return out


def paint_grass(img, ox, oy, rng, flowers=False, dirt_mix=False):
    tone = blotch_map(rng, 7, 4, 1)
    for (x, y) in CELLS:
        t = tone[(x, y)]
        col = GRASS[t]
        r = rng.random()
        if r < 0.08:
            col = GRASS[min(t + 1, 3)]
        elif r < 0.14:
            col = GRASS[max(t - 1, 0)]
        img.putpixel((ox + x, oy + 16 + y), col)
    # 草の房（小さなV字）
    for _ in range(rng.randint(2, 4)):
        x, y = rng.randint(7, 24), rng.randint(3, 12)
        if (x, y) in tone and (x + 1, y) in tone and (x, y - 1) in tone:
            img.putpixel((ox + x, oy + 16 + y), GRASS_DARK)
            img.putpixel((ox + x + 1, oy + 16 + y), GRASS_DARK)
            img.putpixel((ox + x, oy + 16 + y - 1), GRASS[3])
    if dirt_mix:
        dmap = blotch_map(rng, 4, 4, 1)
        cx, cy = rng.randint(10, 21), rng.randint(5, 10)
        for (x, y) in CELLS:
            if math.hypot((x - cx) / 1.0, (y - cy) * 2.0) < rng.uniform(3.5, 6.5):
                img.putpixel((ox + x, oy + 16 + y), DIRT[dmap[(x, y)]])
    if flowers:
        for _ in range(rng.randint(2, 3)):
            x, y = rng.randint(8, 23), rng.randint(4, 11)
            if (x, y) in tone:
                img.putpixel((ox + x, oy + 16 + y), rng.choice([WHITE, WHITE, YELLOW, PINK]))


def paint_dirt(img, ox, oy, rng):
    tone = blotch_map(rng, 6, 4, 1)
    for (x, y) in CELLS:
        t = tone[(x, y)]
        col = DIRT[t]
        if rng.random() < 0.1:
            col = DIRT[(t + 1) % 4]
        img.putpixel((ox + x, oy + 16 + y), col)
    for _ in range(3):  # 小石
        x, y = rng.randint(8, 23), rng.randint(4, 11)
        if (x, y) in tone:
            img.putpixel((ox + x, oy + 16 + y), STONE[1])


def paint_paving(img, ox, oy, rng):
    # 不規則な石：最近傍の点で石を分け、境目を目地にする
    seeds = [(rng.uniform(2, 30), rng.uniform(1, 15), rng.randint(0, 2)) for _ in range(8)]
    for (x, y) in CELLS:
        ranked = sorted(seeds, key=lambda s: (s[0] - x) ** 2 + ((s[1] - y) * 2) ** 2)
        d1 = (ranked[0][0] - x) ** 2 + ((ranked[0][1] - y) * 2) ** 2
        d2 = (ranked[1][0] - x) ** 2 + ((ranked[1][1] - y) * 2) ** 2
        if math.sqrt(d2) - math.sqrt(d1) < 1.3:
            col = MORTAR
        else:
            col = STONE[ranked[0][2]]
            if rng.random() < 0.08:
                col = STONE[(ranked[0][2] + 1) % 3]
        img.putpixel((ox + x, oy + 16 + y), col)
    for _ in range(3):  # 石のすき間の草
        x, y = rng.randint(8, 23), rng.randint(4, 11)
        if (x, y) in dict.fromkeys(CELLS):
            img.putpixel((ox + x, oy + 16 + y), GRASS[1])


# ---- 壁（木と茂み） ----
LEAF_OUT = hx('#1d4a2a')
LEAF = [hx('#2c6a35'), hx('#3a7f3d'), hx('#4d9a45'), hx('#69b552')]  # 暗い→明るい
TRUNK = [hx('#5a3d24'), hx('#6e4a2c')]


def paint_blob(img, ox, circles, rng):
    """丸を重ねた葉のかたまり。左上ほど明るく、縁は暗い線"""
    inside = {}
    for y in range(W):
        for x in range(W):
            for (cx, cy, r) in circles:
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    inside[(x, y)] = (cx, cy, r)
                    break
    for (x, y), (cx, cy, r) in inside.items():
        edge = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            col = LEAF_OUT
        else:
            # 左上からの光：円の中心から見た左上側ほど明るい
            lit = ((cx - x) * 0.7 + (cy - y) * 1.0) / r  # +で左上寄り
            idx = 2 if lit > 0.25 else (1 if lit > -0.35 else 0)
            if rng.random() < 0.18:
                idx = min(3, idx + 1)
            elif rng.random() < 0.1:
                idx = max(0, idx - 1)
            col = LEAF[idx]
        img.putpixel((ox + x, y), col)


ROCK = [hx('#5b5f66'), hx('#767b82'), hx('#90969c'), hx('#a9aeb2')]
ROCK_OUT = hx('#2e3238')


def paint_trunk(img, ox, x0, x1, y0, y1):
    for y in range(y0, y1):
        for x in range(x0, x1):
            img.putpixel((ox + x, y), TRUNK[0] if x >= (x0 + x1) // 2 else TRUNK[1])


def paint_tree(img, ox, v, rng):
    global LEAF
    if v == 0:    # 丸い広葉樹
        paint_trunk(img, ox, 13, 19, 20, 28)
        paint_blob(img, ox, [(16, 10, 11), (9, 15, 8), (23, 15, 8), (16, 17, 8)], rng)
    elif v == 1:  # 細長い針葉樹（暗い緑）
        paint_trunk(img, ox, 14, 18, 22, 28)
        saved = LEAF
        LEAF = [hx('#1f4f33'), hx('#2a6540'), hx('#38804d'), hx('#4a9a5c')]
        paint_blob(img, ox, [(16, 6, 6), (16, 11, 8), (16, 17, 9)], rng)
        LEAF = saved
    elif v == 2:  # 大きな木（幹が見える）
        paint_trunk(img, ox, 12, 20, 18, 28)
        paint_blob(img, ox, [(16, 8, 13), (7, 13, 7), (25, 13, 7)], rng)
    else:         # 岩山（高い岩）
        paint_rock(img, ox, [(16, 14, 12), (8, 20, 8), (24, 20, 8)], rng)


def paint_rock(img, ox, circles, rng):
    inside = {}
    for y in range(W):
        for x in range(W):
            for (cx, cy, r) in circles:
                if (x + 0.5 - cx) ** 2 + ((y + 0.5 - cy) * 1.15) ** 2 <= r * r:
                    inside[(x, y)] = (cx, cy, r)
                    break
    for (x, y), (cx, cy, r) in inside.items():
        edge = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            col = ROCK_OUT
        else:
            lit = ((cx - x) * 0.6 + (cy - y) * 1.0) / r
            idx = 3 if lit > 0.55 else (2 if lit > 0.1 else (1 if lit > -0.4 else 0))
            if (x * 3 + y * 5) % 11 == 0:
                idx = max(0, idx - 1)
            col = ROCK[idx]
        img.putpixel((ox + x, y), col)


def paint_bush(img, ox, v, rng):
    if v == 0:
        paint_blob(img, ox, [(16, 19, 8), (9, 22, 6), (23, 22, 6)], rng)
    elif v == 1:  # 花の茂み
        paint_blob(img, ox, [(16, 20, 8), (10, 23, 6), (22, 23, 6)], rng)
        for (x, y) in [(13, 18), (19, 20), (10, 22), (22, 23)]:
            img.putpixel((ox + x, y), WHITE if (x + y) % 2 else YELLOW)
    else:         # 低い岩
        paint_rock(img, ox, [(16, 21, 8), (9, 24, 6), (23, 24, 6)], rng)


def main():
    img = Image.new('RGBA', (W * 4, W * VARIANTS), (0, 0, 0, 0))
    for v in range(VARIANTS):
        for s in range(2):
            rng = random.Random(2000 + v * 10 + s * 3)
            ox, oy = s * W, v * W
            if v < 4:
                paint_grass(img, ox, oy, rng)
            elif v == 4:
                paint_grass(img, ox, oy, rng, flowers=True)
            elif v == 5:
                paint_dirt(img, ox, oy, rng)
            elif v == 6:
                paint_paving(img, ox, oy, rng)
            else:
                paint_grass(img, ox, oy, rng, dirt_mix=True)
    # 壁：列2=高い壁（行0=広葉樹 1=針葉樹 2=大木 3=岩山）、列3=低い壁（行0=茂み 1=花の茂み 2=低い岩）
    for v in range(4):
        tmp = Image.new('RGBA', (W, W), (0, 0, 0, 0))
        paint_tree(tmp, 0, v, random.Random(7 + v))
        img.paste(tmp, (W * 2, W * v))
    for v in range(3):
        tmp = Image.new('RGBA', (W, W), (0, 0, 0, 0))
        paint_bush(tmp, 0, v, random.Random(17 + v))
        img.paste(tmp, (W * 3, W * v))
    img.save('art/tiles/grounds_tiles.png')
    print('ok', img.size)


main()
