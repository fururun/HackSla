"""廃寺の地下墓所の、床と壁のタイルを作る（コードで描く、継ぎ目のない32×16の菱形）。
出力: art/tiles/crypt_tiles.png（128×256。4列×8行。列0・1=床（市松の2色）、列2=奥の壁（高い）、列3=手前の壁（低い）。行=模様の違い）
色は、Muse が出した「彩度を上げた」モックから取った（藍・青緑の石、暗い目地、苔の緑）。
実行: python tools/tiles/make_crypt_tiles.py
"""
import random
from PIL import Image

W = 32
VARIANTS = 8

def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

# 石畳の色（明るい→暗い）。モックの床の青緑〜藍から
STONE = [hx('#215b7c'), hx('#1c4f6e'), hx('#17435f'), hx('#133850'), hx('#0f2d42')]
MORTAR = hx('#0b1430')
EDGE_LIGHT = hx('#2a6f92')   # 左上の縁（光が当たる）
EDGE_DARK = hx('#0b1a33')    # 右下の縁（影）
MOSS = [hx('#2a7a47'), hx('#3d9460'), hx('#1a5230')]
GLOW = hx('#e8a63a')         # ひびに染み出す灯りの色（ごく少量）

def shade_color(c, k):
    return (int(c[0] * k), int(c[1] * k), int(c[2] * k), 255)

def paint_floor(img, ox, oy, variant, shade, rng):
    base_k = 1.0 if shade == 0 else 0.93
    # 目地の位置（模様ごとに少しずらす）。a・b は、菱形の2辺に沿った 0〜1 の座標
    ja = 0.5 + rng.uniform(-0.12, 0.12)
    jb = 0.5 + rng.uniform(-0.12, 0.12)
    cracked = variant in (3, 5, 7)
    mossy = variant in (4, 5, 6)
    cells = {}
    for y in range(16):
        for x in range(W):
            px = (x + 0.5) / W * 2 - 1
            py = (y + 0.5) / 16 * 2 - 1
            d = abs(px) + abs(py)
            if d > 1.0:
                continue
            a = (px + py + 1) / 2
            b = (px - py + 1) / 2
            cells[(x, y)] = (a, b, d)
    # 石板ごとの明るさ（2×2 の4枚。a,b の境目が目地）
    slab_tone = {}
    for sa in (0, 1):
        for sb in (0, 1):
            slab_tone[(sa, sb)] = rng.randint(0, 3)
    for (x, y), (a, b, d) in cells.items():
        sa = 0 if a < ja else 1
        sb = 0 if b < jb else 1
        tone = slab_tone[(sa, sb)]
        col = STONE[tone]
        # ざらつき（石の粒）
        r = rng.random()
        if r < 0.07:
            col = STONE[min(tone + 1, 4)]
        elif r < 0.11:
            col = STONE[max(tone - 1, 0)]
        # 板の左上寄りを少し明るく（光は左上から）
        if abs(a - ja) < 0.06 and a > ja or abs(b - jb) < 0.06 and b > jb:
            col = STONE[max(tone - 1, 0)]
        # 目地（板と板のあいだ）
        if abs(a - ja) < 0.035 or abs(b - jb) < 0.035:
            col = MORTAR
        # 縁：左上の2辺は明るく、右下の2辺は暗く（隣のタイルとの継ぎ目の線）
        if d > 0.88:
            col = EDGE_LIGHT if (y < 8) else EDGE_DARK
            if rng.random() < 0.25:
                col = MORTAR
        img.putpixel((ox + x, oy + 16 + y), shade_color(col, base_k) if col not in (MORTAR, EDGE_LIGHT, EDGE_DARK) else col)
    # ひび割れ：縁から離れた位置に、短い折れ線（隣のタイルとつながらないよう、内側だけ）
    if cracked:
        cx, cy = rng.randint(11, 20), rng.randint(3, 9)
        for i in range(rng.randint(5, 8)):
            if (cx, cy) in cells and cells[(cx, cy)][2] < 0.78:
                img.putpixel((ox + cx, oy + 16 + cy), MORTAR)
                if rng.random() < 0.18:
                    img.putpixel((ox + cx, oy + 16 + min(cy + 1, 15)), GLOW)
            cx += rng.choice([-1, 0, 1, 1]); cy += rng.choice([0, 1, 1])
    # 苔：内側に、ぽつぽつ塊で（縁には出さない）
    if mossy:
        for _ in range(rng.randint(2, 4)):
            mx, my = rng.randint(8, 23), rng.randint(3, 11)
            for dx in range(-2, 3):
                for dy in range(-1, 2):
                    p = (mx + dx, my + dy)
                    if p in cells and cells[p][2] < 0.8 and rng.random() < 0.6 - 0.15 * (abs(dx) + abs(dy)):
                        img.putpixel((ox + p[0], oy + 16 + p[1]), rng.choice(MOSS))

# 壁（高さ：奥の壁=16、手前の壁=4）。形は iso_map.gd の _paint_wall と同じ
W_TOP = hx('#35607f')
W_TOP_LIGHT = hx('#5e9cc0')
W_LEFT = [hx('#27456e'), hx('#223c63'), hx('#2d4d78')]
W_RIGHT = [hx('#16264a'), hx('#12203f'), hx('#1a2d55')]
W_MORTAR = hx('#0a1330')

def paint_wall(img, ox, height, rng):
    top_c = 24.0 - height
    for y in range(W):
        for x in range(W):
            w = 1.0 - abs(x + 0.5 - 16.0) / 16.0
            top_lo = top_c - 8.0 * w
            top_hi = top_c + 8.0 * w
            bottom = 24.0 + 8.0 * w
            py = y + 0.5
            if top_lo <= py <= top_hi:
                col = W_TOP_LIGHT if py < top_lo + 1.0 else W_TOP
                if rng.random() < 0.10:
                    col = shade_color(col, 0.9)
                img.putpixel((ox + x, y), col)
            elif top_hi < py <= bottom:
                course_y = int(py - top_hi)
                course = course_y // 5
                mortar = course_y % 5 == 4 or (x + course * 5) % 10 == 0
                palette = W_LEFT if x < 16 else W_RIGHT
                col = W_MORTAR if mortar else palette[(x // 5 + course) % 3]
                # 苔：壁の根もと（下の方）に、少し
                if not mortar and py > bottom - 4 and rng.random() < 0.22:
                    col = rng.choice(MOSS)
                img.putpixel((ox + x, y), col)

def main():
    img = Image.new('RGBA', (W * 4, W * VARIANTS), (0, 0, 0, 0))
    for v in range(VARIANTS):
        for s in range(2):
            rng = random.Random(1000 + v * 10)  # 同じ模様で、明るさだけ違う2枚（市松）
            paint_floor(img, s * W, v * W, v, s, rng)
    for v in range(VARIANTS):
        # 壁は先頭の行だけ使う（ほかの行は空）。奥の壁・手前の壁
        pass
    paint_wall(img, W * 2, 16.0, random.Random(7))
    paint_wall(img, W * 3, 4.0, random.Random(8))
    img.save('art/tiles/crypt_tiles.png')
    print('ok', img.size)

main()
