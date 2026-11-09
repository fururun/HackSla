"""地下墓所の床を、マップ全体で1枚の絵にする（大きな不規則な石畳。複数のマスにまたがる）。
入力: data/maps/field_01.txt   出力: art/tiles/mural_field_01_crypt.png
床のマス（# 以外）の菱形の中だけを塗る。絵の座標は、IsoMap の map_to_local と同じ規則で、
  マス(x,y)の中心 = ((x-y)*16+16+OX, (x+y)*8+8)  （OX は左の余白）
IsoMap が、この絵を床の上に敷く（床のタイルは、当たり判定・印のために残して隠す）。
実行: python tools/tiles/make_floor_mural.py   （マップを作り直したら、もう一度実行する）
"""
import os
import numpy as np
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, '..', '..')
rows = [l.rstrip('\n') for l in open(os.path.join(root, 'data', 'maps', 'field_01.txt'), encoding='utf-8') if l.strip()]
H = len(rows)
W = max(len(r) for r in rows)
OX = (H - 1) * 16
IW = (W + H) * 16
IH = (W + H - 2) * 8 + 16

rng = np.random.default_rng(20261109)


def hx(s):
    s = s.lstrip('#')
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


STONE = [hx('#2c5d68'), hx('#33696f'), hx('#3b7479'), hx('#27525e'), hx('#305a6e')]  # 青緑〜青灰
MORTAR = hx('#0b1430')
LIGHT = hx('#6fb0b0')
DARK = hx('#0f2030')
MOSS = [hx('#245f3c'), hx('#2f7a4d'), hx('#174a2c')]
RUST = hx('#5a3a46')   # 赤茶の染み

# ---- ピクセル → 地面の座標 (u,v)（マス単位） ----
ys, xs = np.mgrid[0:IH, 0:IW].astype(np.float32)
lx = xs + 0.5 - OX
ly = ys + 0.5
u = ((lx - 16) / 16 + ly / 8) / 2
v = (ly / 8 - (lx - 16) / 16) / 2
cu = np.floor(u).astype(int)
cv = np.floor(v).astype(int)

floor = np.zeros((IH, IW), dtype=bool)
inside = (cu >= 0) & (cu < W) & (cv >= 0) & (cv < H)
grid = np.zeros((H, W), dtype=bool)
for y, r in enumerate(rows):
    for x, c in enumerate(r):
        grid[y, x] = c != '#'
floor[inside] = grid[cv[inside], cu[inside]]

# ---- 値ノイズ（なめらかな、場所ごとの偏り。大きな石の区画・がれきの区画・苔の区画に使う）----
def value_noise(scale, seed):
    r = np.random.default_rng(seed)
    g = r.random((int(H / scale) + 3, int(W / scale) + 3)).astype(np.float32)
    fu = u / scale
    fv = v / scale
    iu = np.clip(np.floor(fu).astype(int), 0, g.shape[1] - 2)
    iv = np.clip(np.floor(fv).astype(int), 0, g.shape[0] - 2)
    tu = np.clip(fu - iu, 0, 1)
    tv = np.clip(fv - iv, 0, 1)
    tu = tu * tu * (3 - 2 * tu)
    tv = tv * tv * (3 - 2 * tv)
    a = g[iv, iu] * (1 - tu) + g[iv, iu + 1] * tu
    b = g[iv + 1, iu] * (1 - tu) + g[iv + 1, iu + 1] * tu
    return a * (1 - tv) + b * tv


def voronoi(cell, angular, salt):
    """格子ごとに1点をずらして置き、最近傍で石を分ける。angular が大きいほど四角っぽい石になる"""
    gx = np.floor(u / cell).astype(int)
    gy = np.floor(v / cell).astype(int)
    best = np.full((IH, IW), 1e9, dtype=np.float32)
    second = np.full((IH, IW), 1e9, dtype=np.float32)
    bid = np.zeros((IH, IW), dtype=int)
    bdx = np.zeros((IH, IW), dtype=np.float32)
    bdy = np.zeros((IH, IW), dtype=np.float32)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            ix, iy = gx + ox, gy + oy
            h = (ix * 73856093) ^ (iy * 19349663) ^ salt
            h = (h ^ (h >> 13)) * 1274126177
            h = h ^ (h >> 16)
            sx = (ix + ((h & 0xFFFF) / 65535.0) * 0.7 + 0.15) * cell
            sy = (iy + (((h >> 16) & 0xFFFF) / 65535.0) * 0.7 + 0.15) * cell
            dx = u - sx
            dy = v - sy
            d = (1 - angular) * np.sqrt(dx * dx + dy * dy) + angular * np.maximum(np.abs(dx), np.abs(dy)) * 1.15
            better = d < best
            second = np.where(better, best, np.minimum(second, d))
            bdx = np.where(better, dx, bdx)
            bdy = np.where(better, dy, bdy)
            bid = np.where(better, (h >> 5) & 0xFFFF, bid)
            best = np.where(better, d, best)
    return second - best, bid, bdx, bdy


noise = rng.random((IH, IW))
region = value_noise(5.0, 11)    # 大きな石の区画 ↔ 小さな石の区画
rubble_zone = value_noise(4.0, 23)  # がれき（小石の散らばり）の区画
moss_zone = value_noise(3.5, 37)
stain_zone = value_noise(6.0, 41)

gap_b, id_b, dx_b, dy_b = voronoi(3.0, 0.55, 0x1111)   # 大きな板石
gap_m, id_m, dx_m, dy_m = voronoi(1.5, 0.30, 0x2222)   # 中くらいの石
gap_s, id_s, dx_s, dy_s = voronoi(0.8, 0.10, 0x3333)   # 小さな石
use_big = region > 0.55
use_small = region < 0.30
gap = np.where(use_big, gap_b, np.where(use_small, gap_s, gap_m))
sid = np.where(use_big, id_b, np.where(use_small, id_s, id_m))
sdx = np.where(use_big, dx_b, np.where(use_small, dx_s, dx_m))
sdy = np.where(use_big, dy_b, np.where(use_small, dy_s, dy_m))
width = np.where(use_big, 0.20, np.where(use_small, 0.13, 0.17))  # 縁の幅（マス）：大きな石ほど厚み

img = np.zeros((IH, IW, 3), dtype=np.float32)
tone_idx = sid % len(STONE)
for i, col in enumerate(STONE):
    img[tone_idx == i] = col
bright = 1.0 + ((sid >> 3) % 9 - 4) * 0.04
img *= bright[..., None]
img *= (1.0 + (noise - 0.5) * 0.03)[..., None]       # 石の粒（ごく弱く。ざらつかせない）
# 地面（がれきの区画）：暗い土に、小石を散らす
rub = rubble_zone > 0.62
ground = np.where(rub[..., None], hx('#17283a'), img)
img = ground
gap_p, id_p, dx_p, dy_p = voronoi(0.42, 0.0, 0x4444)   # 小石：1個ずつ丸い塊にする
pebble = rub & (gap_p > 0.07) & (((id_p >> 2) % 3) == 0) & (np.sqrt(dx_p ** 2 + dy_p ** 2) < 0.17)
pebble_lit = pebble & ((dx_p + dy_p) < 0)
img[pebble] = hx('#35687a')
img[pebble_lit] = hx('#5e9a9e')
# 縁取り：左上の縁は明るく、右下の縁は暗く。大きな石ほど厚い
facing = (sdx + sdy) > 0
edge = (gap < width) & ~rub
img[edge & ~facing] = img[edge & ~facing] * 0.5 + LIGHT * 0.5
img[edge & facing] = img[edge & facing] * 0.45 + DARK * 0.55
mortar = (gap < 0.055) & ~rub
img[mortar] = MORTAR
# 割れ目・砂利・苔・染み
mossy = (moss_zone > 0.68) & (value_noise(1.1, 91) > 0.45)
for i, col in enumerate(MOSS):
    sel = mossy & ((value_noise(0.8, 95) > 0.5) if i == 0 else ((value_noise(0.8, 96) > 0.35) if i == 1 else (value_noise(0.8, 97) > 0.75)))
    if i != 0:
        sel &= ~(mossy & (value_noise(0.8, 95) > 0.5)) if i == 2 else sel
    img[sel] = col
rusty = (stain_zone < 0.28) & (value_noise(1.2, 99) > 0.4)
img[rusty] = img[rusty] * 0.55 + RUST * 0.45
# 床の端（壁・崖のきわ）：欠けた石とがれき。縁から 0.6 マス以内に、暗い点と小石を散らす
nb = np.zeros((IH, IW), dtype=bool)
wallgrid = ~grid
for dy_ in (-1, 0, 1):
    for dx_ in (-1, 0, 1):
        if dx_ == 0 and dy_ == 0:
            continue
        ncu = np.clip(cu + dx_, 0, W - 1)
        ncv = np.clip(cv + dy_, 0, H - 1)
        nb |= inside & wallgrid[ncv, ncu]
fu_ = u - cu
fv_ = v - cv
near_edge = nb & floor & ((np.minimum(fu_, 1 - fu_) < 0.45) | (np.minimum(fv_, 1 - fv_) < 0.45))
debris = near_edge & (value_noise(0.6, 101) > 0.62)
img[debris] = img[debris] * 0.5 + DARK * 0.5
debris2 = near_edge & (gap_p > 0.07) & (((id_p >> 2) % 4) == 0) & (np.sqrt(dx_p ** 2 + dy_p ** 2) < 0.15)
img[debris2] = hx('#4f8088')

out = np.zeros((IH, IW, 4), dtype=np.uint8)
out[..., :3] = np.clip(img, 0, 255).astype(np.uint8)
out[..., 3] = np.where(floor, 255, 0)
dest = os.path.join(root, 'art', 'tiles', 'mural_field_01_crypt.png')
Image.fromarray(out, 'RGBA').save(dest)
print(dest, IW, IH, 'OX', OX)
