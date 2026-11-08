# ChatGPT が作った攻撃モーション（source/attack/attack_{front,side,back}_sheet.png、5コマ、緑の背景）を、ゲームで使う大きさに縮める。
#   python art/sprites/player/make_attack.py
# 出力：player_attack_{front,side,back}_{0..4}.png（48x40）。コマの並びは、0:構え 1:振りかぶり 2:斬り下ろし（白い弧つき） 3:残心 4:構えに戻る。
# 斬撃の弧や、振りかぶった刀が、立ち絵の枠（30x30）からはみ出すので、広い枠（48x40）に描く。
# 大きさは、いまの立ち絵（player_{front,side,back}.png）に合わせる：構えのコマ（0）の人の高さを、立ち絵の高さに合わせる。
# 位置は、構えのコマ（0）の足元の中央を、枠の下の近く（足元の行 FEET_ROW、横の中央）に合わせる。
# 5コマとも同じ窓で切り出す（コマごとの踏み込みや体の傾きが、そのまま残る）。
# 縮め方は make_small.py と同じ（透明部分の色が混ざらないよう、アルファ付きで平均。縁は、アルファ0.45以上で不透明）。
import os
import numpy as np
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
OUT_W, OUT_H = 48, 40
FEET_ROW = 37
FRAMES = 5
VIEWS = ('front', 'side', 'back')


def key_green(im):
    a = np.asarray(im.convert('RGB')).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = (g > 140) & (g - r > 60) & (g - b > 60)
    alpha = np.where(green, 0, 255).astype(np.uint8)
    return np.dstack([a.astype(np.uint8), alpha])


def bbox(rgba):
    ys, xs = np.where(rgba[..., 3] > 0)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def feet_center(rgba):
    """外枠の下の1割の行にある、不透明な点の横の平均（足元の中央）"""
    x0, y0, x1, y1 = bbox(rgba)
    top = y1 - max(1, int((y1 - y0) * 0.1))
    ys, xs = np.where(rgba[top:y1, :, 3] > 0)
    return float(xs.mean())


def shrink(window_rgba):
    a = window_rgba.astype(np.float32) / 255.0
    pm = a.copy()
    pm[..., :3] *= a[..., 3:4]
    chans = [np.asarray(Image.fromarray((pm[..., c] * 255).round().astype(np.uint8)).resize((OUT_W, OUT_H), Image.BOX)) for c in range(4)]
    small = np.stack(chans, -1).astype(np.float32) / 255.0
    al = small[..., 3:4]
    rgb = np.where(al > 0.01, small[..., :3] / np.maximum(al, 1e-4), 0)
    out = np.concatenate([np.clip(rgb, 0, 1), (al > 0.45).astype(np.float32)], -1)
    return Image.fromarray((out * 255).round().astype(np.uint8), 'RGBA')


for view in VIEWS:
    path = os.path.join(here, 'source', 'attack', 'attack_%s_sheet.png' % view)
    sheet = Image.open(path).convert('RGB')
    cell_w = sheet.width // FRAMES
    cells = [key_green(sheet.crop((i * cell_w, 0, (i + 1) * cell_w, sheet.height))) for i in range(FRAMES)]
    ref = np.asarray(Image.open(os.path.join(here, 'player_%s.png' % view)).convert('RGBA'))
    _, ry0, _, ry1 = bbox(ref)
    ref_h = ry1 - ry0
    sx0, sy0, sx1, sy1 = bbox(cells[0])
    src_h = sy1 - sy0
    win_h = int(round(src_h * OUT_H / float(ref_h)))
    win_w = int(round(src_h * OUT_W / float(ref_h)))
    fx = feet_center(cells[0])
    wx0 = int(round(fx - win_w * 0.5))
    wy0 = int(round(sy1 - win_h * (FEET_ROW / float(OUT_H))))
    for i, cell in enumerate(cells):
        h, w = cell.shape[:2]
        canvas = np.zeros((win_h, win_w, 4), dtype=np.uint8)
        x0, y0 = max(wx0, 0), max(wy0, 0)
        x1, y1 = min(wx0 + win_w, w), min(wy0 + win_h, h)
        canvas[y0 - wy0:y1 - wy0, x0 - wx0:x1 - wx0] = cell[y0:y1, x0:x1]
        shrink(canvas).save(os.path.join(here, 'player_attack_%s_%d.png' % (view, i)))
    print(view, 'window', win_w, win_h, 'ref_h', ref_h, 'src_h', src_h)
print('ok')
