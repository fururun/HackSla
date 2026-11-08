# ChatGPT が作った歩きの4コマ（source/walk/walk_{front,side,back}_sheet.png、緑の背景）を、ゲームで使う大きさに縮める。
#   python art/sprites/player/make_walk.py
# 出力：player_walk_{front,side,back}_{0..3}.png（30x30）。コマの並びは、0:足を前に出す 1:そろう 2:反対の足を前に出す 3:そろう。
# 大きさと位置は、いま使っている立ち絵（player_{front,side,back}.png）に合わせる：
#   立ち姿のコマ（1）の外枠の高さを、立ち絵の外枠の高さに合わせ、足元の中央を、立ち絵の足元の中央に合わせる。
#   4コマとも同じ窓で切り出す（コマごとの上下の弾みや足の位置の違いが、そのまま残る）。
# 縮め方は make_small.py と同じ（透明部分の色が混ざらないよう、アルファ付きで平均。縁は、アルファ0.45以上で不透明）。
import os
import numpy as np
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
SIZE = 30
FRAMES = 4


def key_green(im):
    a = np.asarray(im.convert('RGB')).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = (g > 140) & (g - r > 60) & (g - b > 60)
    alpha = np.where(green, 0, 255).astype(np.uint8)
    out = np.dstack([a.astype(np.uint8), alpha])
    return out


def bbox(rgba):
    ys, xs = np.where(rgba[..., 3] > 0)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def shrink(window_rgba):
    a = window_rgba.astype(np.float32) / 255.0
    pm = a.copy()
    pm[..., :3] *= a[..., 3:4]
    chans = [np.asarray(Image.fromarray((pm[..., c] * 255).round().astype(np.uint8)).resize((SIZE, SIZE), Image.BOX)) for c in range(4)]
    small = np.stack(chans, -1).astype(np.float32) / 255.0
    al = small[..., 3:4]
    rgb = np.where(al > 0.01, small[..., :3] / np.maximum(al, 1e-4), 0)
    out = np.concatenate([np.clip(rgb, 0, 1), (al > 0.45).astype(np.float32)], -1)
    return Image.fromarray((out * 255).round().astype(np.uint8), 'RGBA')


for view in ('front', 'side', 'back'):
    sheet = Image.open(os.path.join(here, 'source', 'walk', 'walk_%s_sheet.png' % view)).convert('RGB')
    cell_w = sheet.width // FRAMES
    cells = [key_green(sheet.crop((i * cell_w, 0, (i + 1) * cell_w, sheet.height))) for i in range(FRAMES)]
    # いまの立ち絵の、外枠と足元の中央
    ref = np.asarray(Image.open(os.path.join(here, 'player_%s.png' % view)).convert('RGBA'))
    rx0, ry0, rx1, ry1 = bbox(ref)
    ref_h = ry1 - ry0
    ref_cx = (rx0 + rx1) / 2.0
    ref_bottom = ry1  # 外枠の下の端（行の数）
    # 立ち姿のコマ（1）の外枠
    sx0, sy0, sx1, sy1 = bbox(cells[1])
    src_h = sy1 - sy0
    win = int(round(src_h * SIZE / float(ref_h)))  # 窓の一辺（元の絵のドット）
    cx = (sx0 + sx1) / 2.0
    wx0 = int(round(cx - win * (ref_cx / SIZE)))
    wy0 = int(round(sy1 - win * (ref_bottom / SIZE)))
    for i, cell in enumerate(cells):
        h, w = cell.shape[:2]
        canvas = np.zeros((win, win, 4), dtype=np.uint8)
        # 窓が絵の外にはみ出すところは、透明のまま
        x0, y0 = max(wx0, 0), max(wy0, 0)
        x1, y1 = min(wx0 + win, w), min(wy0 + win, h)
        canvas[y0 - wy0:y1 - wy0, x0 - wx0:x1 - wx0] = cell[y0:y1, x0:x1]
        shrink(canvas).save(os.path.join(here, 'player_walk_%s_%d.png' % (view, i)))
    print(view, 'window', win, 'ref_h', ref_h, 'src_h', src_h)
print('ok')
