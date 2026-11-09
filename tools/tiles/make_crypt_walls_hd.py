"""地下墓所の壁を、2倍の細かさ（ドットが半分の大きさ）で作る。
出力: art/tiles/crypt_walls_tall_hd.png（64×96 を6種類 横に並べる。高い壁＝2階分）
      art/tiles/crypt_walls_low_hd.png（64×64 を3種類。低い壁）
IsoMap が、半分の大きさで、壁のマスごとに重ねる（当たり判定は今までのタイルのまま）。
種類（高い壁）: 0=普通 1=アーチ 2=窓 3=扉 4=崩れ 5=苔 / （低い壁）0=普通 1=崩れ 2=苔
実行: python tools/tiles/make_crypt_walls_hd.py
"""
import random
from PIL import Image

W = 64   # 1マス幅（2倍）


def hx(s):
    s = s.lstrip('#')
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def shade(c, k):
    return (min(255, int(c[0] * k)), min(255, int(c[1] * k)), min(255, int(c[2] * k)), 255)


TOP = hx('#2f6370')
TOP_LIGHT = hx('#5ba3a6')
TOP_DARK = hx('#274f5c')
BRICK_L = [hx('#7a4a45'), hx('#6d4140'), hx('#86544b'), hx('#734542')]
BRICK_R = [hx('#4a2a35'), hx('#402535'), hx('#553240'), hx('#472833')]
MORTAR = hx('#2a1426')
DARK = hx('#120a1c')
FRAME = hx('#b58a62')
GLOW = hx('#ffb454')
WOOD = hx('#6b4426')
DOORGLOW = hx('#e8893a')
MOSS = [hx('#245f3c'), hx('#2f7a4d'), hx('#174a2c')]

COURSE = 8      # レンガ1段の高さ
BRICK = 16      # レンガ1個の幅


def feature(kind, x, ry, face_h):
    """面の中の位置（x=0..31, ry=0..face_h）の窓・扉・アーチ。色を返す（なければ None）"""
    bottom = ry - (face_h - 32)   # 下の階の座標（0..32）
    if kind == 'window':
        for base in (ry, bottom):
            if base >= 0 and 12 <= x <= 19 and 8 <= base <= 19:
                inner = 14 <= x <= 17 and 10 <= base <= 17
                return (GLOW if base < 15 else shade(GLOW, 0.8)) if inner else (FRAME if (x in (12, 19) or base in (8, 19)) else DARK)
    elif kind == 'arch' and bottom >= 0:
        cx = 15.5
        top = 8 + int(max(0.0, abs(x - cx) - 4) * 0.9)
        if 7 <= x <= 24 and bottom >= top:
            return DARK
        if 6 <= x <= 25 and bottom >= top - 2 and (x in (6, 7, 24, 25) or bottom <= top):
            return FRAME
    elif kind == 'door' and bottom >= 0:
        if 10 <= x <= 21 and bottom >= 6:
            if x in (10, 21):
                return DOORGLOW
            return WOOD if (x + bottom // 6) % 5 else DARK
        if 9 <= x <= 22 and bottom >= 4:
            return FRAME
    return None


def paint(img, height_hd, kind, rng, canvas_h, foot):
    top_c = foot - height_hd
    brick_tone = {}
    for y in range(canvas_h):
        for x in range(W):
            w = 1.0 - abs(x + 0.5 - 32.0) / 32.0
            top_lo = top_c - 16.0 * w
            top_hi = top_c + 16.0 * w
            bottom = foot + 16.0 * w
            py = y + 0.5
            if top_lo <= py <= top_hi:
                col = TOP_LIGHT if py < top_lo + 2.0 else (TOP_DARK if py > top_hi - 1.5 else TOP)
                if rng.random() < 0.08:
                    col = shade(col, 0.92)
                if kind == 'crumbled' and rng.random() < 0.08:
                    continue
                img.putpixel((x, y), col)
            elif top_hi < py <= bottom:
                ry = py - top_hi
                left = x < 32
                fx = x if left else x - 32
                course = int(ry) // COURSE
                inrow = int(ry) % COURSE
                offs = (course % 2) * (BRICK // 2)
                bx = (fx + offs) // BRICK
                bin_x = (fx + offs) % BRICK
                key = (left, course, bx)
                if key not in brick_tone:
                    brick_tone[key] = rng.randint(0, 3)
                pal = BRICK_L if left else BRICK_R
                col = pal[brick_tone[key]]
                if inrow == 0:
                    col = shade(col, 1.18)              # 上縁の明るい線
                if inrow == COURSE - 1 or bin_x == 0:
                    col = MORTAR                        # 目地
                elif inrow == COURSE - 2:
                    col = shade(col, 0.82)              # 下縁の影
                col = shade(col, 1.0 + (rng.random() - 0.5) * 0.10)
                feat = feature(kind, fx, int(ry), int(height_hd))
                if feat is not None:
                    col = feat if left else (shade(feat, 0.7) if feat in (FRAME, WOOD) else feat)
                elif kind == 'crumbled' and col != MORTAR and rng.random() < 0.18:
                    col = DARK if rng.random() < 0.5 else shade(col, 0.7)
                elif kind == 'mossy' and col != MORTAR and rng.random() < 0.30:
                    col = rng.choice(MOSS)
                elif col != MORTAR and py > bottom - 3 and rng.random() < 0.20:
                    col = rng.choice(MOSS)
                img.putpixel((x, y), col)


def main():
    kinds_tall = ['plain', 'arch', 'window', 'door', 'crumbled', 'mossy']
    tall = Image.new('RGBA', (W * 6, 96), (0, 0, 0, 0))
    for v, kind in enumerate(kinds_tall):
        tmp = Image.new('RGBA', (W, 96), (0, 0, 0, 0))
        paint(tmp, 64.0, kind, random.Random(37 + v), 96, 80.0)
        tall.paste(tmp, (W * v, 0))
    tall.save('art/tiles/crypt_walls_tall_hd.png')
    kinds_low = ['plain', 'crumbled', 'mossy']
    low = Image.new('RGBA', (W * 3, 64), (0, 0, 0, 0))
    for v, kind in enumerate(kinds_low):
        tmp = Image.new('RGBA', (W, 64), (0, 0, 0, 0))
        paint(tmp, 8.0, kind, random.Random(47 + v), 64, 48.0)
        low.paste(tmp, (W * v, 0))
    low.save('art/tiles/crypt_walls_low_hd.png')
    print('ok')


main()
