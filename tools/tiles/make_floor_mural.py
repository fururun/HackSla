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
MOSS = [hx('#2a7a47'), hx('#3d9460'), hx('#1a5230')]
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

# ---- 不規則な石：ずらした格子点の最近傍（ボロノイ）。石の大きさは約 1.6〜2.6 マス ----
CELL = 2.1
gx = np.floor(u / CELL).astype(int)
gy = np.floor(v / CELL).astype(int)


def seed_of(ix, iy):
    h = (ix * 73856093) ^ (iy * 19349663) ^ 0x5bd1e995
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    a = ((h & 0xFFFF) / 65535.0) * 0.8 + 0.1
    b = (((h >> 16) & 0xFFFF) / 65535.0) * 0.8 + 0.1
    return (ix + a) * CELL, (iy + b) * CELL, (h >> 5) & 0xFF


best = np.full((IH, IW), 1e9, dtype=np.float32)
second = np.full((IH, IW), 1e9, dtype=np.float32)
best_id = np.zeros((IH, IW), dtype=int)
best_dx = np.zeros((IH, IW), dtype=np.float32)
best_dy = np.zeros((IH, IW), dtype=np.float32)
for oy in (-1, 0, 1):
    for ox in (-1, 0, 1):
        sx, sy, sid = seed_of(gx + ox, gy + oy)
        dx = u - sx
        dy = v - sy
        d = np.sqrt(dx * dx + dy * dy)
        better = d < best
        second = np.where(better, best, np.minimum(second, d))
        best_dx = np.where(better, dx, best_dx)
        best_dy = np.where(better, dy, best_dy)
        best_id = np.where(better, sid, best_id)
        best = np.where(better, d, best)
gap = second - best

# ---- 色 ----
img = np.zeros((IH, IW, 3), dtype=np.float32)
tone_idx = best_id % len(STONE)
for i, col in enumerate(STONE):
    img[tone_idx == i] = col
bright = 1.0 + ((best_id >> 3) % 7 - 3) * 0.035
img *= bright[..., None]
noise = rng.random((IH, IW))
img *= (1.0 + (noise - 0.5) * 0.10)[..., None]       # 石の粒
# 目地と縁取り（左上の縁は明るく、右下の縁は暗く）
edge = gap < 0.17
facing = (best_dx + best_dy) > 0   # 石の中心から見て右下側＝影
img[edge & ~facing] = img[edge & ~facing] * 0.55 + LIGHT * 0.45
img[edge & facing] = img[edge & facing] * 0.55 + DARK * 0.45
mortar = gap < 0.06
img[mortar] = MORTAR
# 割れ目：石の中に、短い暗い線
crack = (noise > 0.985) & (gap > 0.2)
img[crack] = DARK
# 砂利：目地の近くに、明暗の点
gravel = (gap < 0.35) & (noise > 0.93)
img[gravel] = img[gravel] * 0.7 + LIGHT * 0.3
# 苔：低い周波数のかたまり
coarse = rng.random((H // 3 + 2, W // 3 + 2)).astype(np.float32)
mu = np.clip((u / 3).astype(int), 0, coarse.shape[1] - 1)
mv = np.clip((v / 3).astype(int), 0, coarse.shape[0] - 1)
mossy = (coarse[mv, mu] > 0.80) & (noise > 0.55)
for i, col in enumerate(MOSS):
    sel = mossy & (rng.integers(0, 3, (IH, IW)) == i)
    img[sel] = col
# 赤茶の染み（血・錆）
rusty = (coarse[mv, mu] < 0.07) & (noise > 0.6)
img[rusty] = img[rusty] * 0.5 + RUST * 0.5

out = np.zeros((IH, IW, 4), dtype=np.uint8)
out[..., :3] = np.clip(img, 0, 255).astype(np.uint8)
out[..., 3] = np.where(floor, 255, 0)
dest = os.path.join(root, 'art', 'tiles', 'mural_field_01_crypt.png')
Image.fromarray(out, 'RGBA').save(dest)
print(dest, IW, IH, 'OX', OX)
