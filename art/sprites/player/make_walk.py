# ChatGPT が作った歩きの4コマ（source/walk/walk_{front,side,back}_sheet.png、緑の背景）を、ゲームで使う大きさに縮める。
#   python art/sprites/player/make_walk.py
# 出力：player_walk_{front,side,back,diag_down,diag_up}_{0..3}.png（正面・横・背面は30x30、斜めは36x30）。コマの並びは、0:足を前に出す 1:そろう 2:反対の足を前に出す 3:そろう。
# 大きさと位置は、いま使っている立ち絵（player_{front,side,back}.png）に合わせる：
#   立ち姿のコマ（1）の外枠の高さを、立ち絵の外枠の高さに合わせ、足元の中央を、立ち絵の足元の中央に合わせる。
#   4コマとも同じ窓で切り出す（コマごとの上下の弾みや足の位置の違いが、そのまま残る）。
# 縮め方は make_small.py と同じ（透明部分の色が混ざらないよう、アルファ付きで平均。縁は、アルファ0.45以上で不透明）。
import os
import numpy as np
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
FRAMES = 4
VIEWS = {'front': (30, 30), 'side': (30, 30), 'back': (30, 30), 'diag_down': (36, 30), 'diag_up': (36, 30)}  # 向き -> (幅, 高さ)。斜めは立ち絵が横に広い（刀の分）


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


def shrink(window_rgba, size):
    a = window_rgba.astype(np.float32) / 255.0
    pm = a.copy()
    pm[..., :3] *= a[..., 3:4]
    chans = [np.asarray(Image.fromarray((pm[..., c] * 255).round().astype(np.uint8)).resize(size, Image.BOX)) for c in range(4)]
    small = np.stack(chans, -1).astype(np.float32) / 255.0
    al = small[..., 3:4]
    rgb = np.where(al > 0.01, small[..., :3] / np.maximum(al, 1e-4), 0)
    out = np.concatenate([np.clip(rgb, 0, 1), (al > 0.45).astype(np.float32)], -1)
    return Image.fromarray((out * 255).round().astype(np.uint8), 'RGBA')


for view, (out_w, out_h) in VIEWS.items():
    sheet_path = os.path.join(here, 'source', 'walk', 'walk_%s_sheet.png' % view)
    if not os.path.exists(sheet_path):
        continue  # まだ元の絵がない向き
    sheet = Image.open(sheet_path).convert('RGB')
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
    win_h = int(round(src_h * out_h / float(ref_h)))  # 窓の高さ（元の絵のドット）
    win_w = int(round(win_h * out_w / float(out_h)))  # 窓の幅（出力と同じ縦横の比）
    cx = (sx0 + sx1) / 2.0
    wx0 = int(round(cx - win_w * (ref_cx / out_w)))
    wy0 = int(round(sy1 - win_h * (ref_bottom / out_h)))
    for i, cell in enumerate(cells):
        h, w = cell.shape[:2]
        canvas = np.zeros((win_h, win_w, 4), dtype=np.uint8)
        # 窓が絵の外にはみ出すところは、透明のまま
        x0, y0 = max(wx0, 0), max(wy0, 0)
        x1, y1 = min(wx0 + win_w, w), min(wy0 + win_h, h)
        canvas[y0 - wy0:y1 - wy0, x0 - wx0:x1 - wx0] = cell[y0:y1, x0:x1]
        shrink(canvas, (out_w, out_h)).save(os.path.join(here, 'player_walk_%s_%d.png' % (view, i)))
    print(view, 'window', win_w, win_h, 'ref_h', ref_h, 'src_h', src_h)
print('ok')
