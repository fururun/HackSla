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

# 壁（高さ：奥の壁=16、手前の壁=4）。赤茶のレンガに、青緑の笠石。参考画像（暗い遺跡）の色
W_TOP = hx('#2f6370')
W_TOP_LIGHT = hx('#5ba3a6')
W_LEFT = [hx('#7a4a45'), hx('#6d4140'), hx('#86544b')]
W_RIGHT = [hx('#4a2a35'), hx('#402535'), hx('#553240')]
W_MORTAR = hx('#2a1426')
DARK = hx('#120a1c')
FRAME = hx('#b58a62')
GLOWC = hx('#ffb454')
WOOD = hx('#6b4426')
DOORGLOW = hx('#e8893a')

def face_feature(kind, x, ry, rng_hash):
    """面の中の位置(x=0..15（面の中）, ry=0..16)に、窓・扉・アーチを描く。色を返す（なければ None）"""
    if kind == 'arch':
        top = 4 + (abs(x - 8) > 2) * 2 + (abs(x - 8) > 3) * 2
        if 4 <= x <= 12 and ry >= top:
            return DARK
        if 3 <= x <= 13 and ry >= top - 1 and (x in (3, 4, 12, 13) or ry == top - 1 + (abs(x - 8) > 2) * 0):
            return FRAME
    elif kind == 'window':
        if 6 <= x <= 9 and 4 <= ry <= 9:
            return GLOWC if (x in (7, 8) and 5 <= ry <= 8) else DARK
        if 5 <= x <= 10 and 3 <= ry <= 10:
            return FRAME
    elif kind == 'door':
        if 5 <= x <= 10 and ry >= 3:
            if x in (5, 10):
                return DOORGLOW
            return WOOD if (x + ry // 3) % 4 else DARK
        if 4 <= x <= 11 and ry >= 2:
            return FRAME
    return None

def paint_wall(img, ox, height, rng, kind='plain', canvas_h=W, foot=24.0):
    top_c = foot - height
    for y in range(canvas_h):
        for x in range(W):
            w = 1.0 - abs(x + 0.5 - 16.0) / 16.0
            top_lo = top_c - 8.0 * w
            top_hi = top_c + 8.0 * w
            bottom = foot + 8.0 * w
            py = y + 0.5
            if top_lo <= py <= top_hi:
                col = W_TOP_LIGHT if py < top_lo + 1.0 else W_TOP
                if rng.random() < 0.10:
                    col = shade_color(col, 0.9)
                if kind == 'crumbled' and rng.random() < 0.10:
                    continue  # 崩れて欠けた笠石
                img.putpixel((ox + x, y), col)
            elif top_hi < py <= bottom:
                ry = int(py - top_hi)
                course = ry // 5
                mortar = ry % 5 == 4 or (x + course * 5) % 10 == 0
                palette = W_LEFT if x < 16 else W_RIGHT
                col = W_MORTAR if mortar else palette[(x // 5 + course) % 3]
                fx = x if x < 16 else x - 16
                if height > 16:
                    low = ry - (height - 16)   # 下の階（アーチ・扉）。上の階には窓
                    feat = None
                    if kind in ('arch', 'door') and low >= 0:
                        feat = face_feature(kind, fx, low, 0)
                    elif kind == 'window':
                        feat = face_feature('window', fx, ry, 0) or (face_feature('window', fx, low, 0) if low >= 0 else None)
                    elif kind == 'plain' and ry in (height - 17,):
                        feat = None
                    if kind in ('arch', 'door') and feat is None and 3 <= fx <= 12 and 3 <= ry <= 10 and fx % 6 in (2, 3):
                        feat = face_feature('window', fx - (fx % 6 - 2) + 4 - 4, ry, 0) if False else None
                else:
                    feat = face_feature(kind, fx, ry, 0) if height > 8 else None
                if feat is not None:
                    col = feat if x < 16 else shade_color(feat, 0.7) if feat in (FRAME, WOOD) else feat
                elif kind == 'crumbled' and not mortar and rng.random() < 0.2:
                    col = DARK if rng.random() < 0.5 else shade_color(col, 0.7)
                elif kind == 'mossy' and not mortar and rng.random() < 0.28:
                    col = rng.choice(MOSS)
                elif not mortar and py > bottom - 4 and rng.random() < 0.18:
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
    # 列2=高い壁（行0=普通 1=アーチ 2=窓 3=扉 4=崩れた 5=苔むした）、列3=低い壁（行0=普通 1=崩れた 2=苔むした）
    for v, kind in enumerate(['plain', 'arch', 'window', 'door', 'crumbled', 'mossy']):
        tmp = Image.new('RGBA', (W, W), (0, 0, 0, 0))
        paint_wall(tmp, 0, 16.0, random.Random(7 + v), kind)
        img.paste(tmp, (W * 2, W * v))
    for v, kind in enumerate(['plain', 'crumbled', 'mossy']):
        tmp = Image.new('RGBA', (W, W), (0, 0, 0, 0))
        paint_wall(tmp, 0, 4.0, random.Random(17 + v), kind)
        img.paste(tmp, (W * 3, W * v))
    # 2階分の高い壁（32×48）。crypt_walls_tall.png：6種類を横に並べる
    TALL_H = 48
    tall = Image.new('RGBA', (W * 6, TALL_H), (0, 0, 0, 0))
    for v, kind in enumerate(['plain', 'arch', 'window', 'door', 'crumbled', 'mossy']):
        tmp = Image.new('RGBA', (W, TALL_H), (0, 0, 0, 0))
        paint_wall(tmp, 0, 32.0, random.Random(27 + v), kind, canvas_h=TALL_H, foot=40.0)
        tall.paste(tmp, (W * v, 0))
    tall.save('art/tiles/crypt_walls_tall.png')
    img.save('art/tiles/crypt_tiles.png')
    print('ok', img.size)

main()
