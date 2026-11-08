# ChatGPT が作った敵の動きの連結シート（source/anim/*.png、緑の背景）を、ゲームで使う大きさに縮める。
#   python art/sprites/enemies/make_enemy_anim.py
# 出力：enemies/ の中に <名前>_<動き>_<コマ番号>.png。例：rockgolem_walk_0.png
# 大きさは、いま使っている絵（参照の絵）に合わせる：基準のコマの人の高さを、参照の絵の高さに合わせる。
# 位置は、基準のコマの足元の中央を、枠の下・横の中央に合わせる。全コマ同じ窓で切り出す（跳ねる・踏み込みが残る）。
# 縮め方は player/make_small.py と同じ（透明部分の色が混ざらないよう、アルファ付きで平均。縁は、アルファ0.45以上で不透明）。
import os
import sys
import numpy as np
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))

# (出力の名前, 元のシート, コマ数, 参照の絵, 基準のコマ, 出力の幅, 出力の高さ)
SPECS = [
    ('rockgolem_walk', 'golem_walk_sheet.png', 4, 'rockgolem_front.png', 1, 40, 32),
    ('rockgolem_attack', 'golem_attack_sheet.png', 5, 'rockgolem_front.png', 0, 40, 32),
    ('slime_move', 'slime_move_sheet.png', 4, None, 0, 24, 18),
    ('slime_attack', 'slime_attack_sheet.png', 4, None, 0, 24, 18),
    ('spitter_move', 'spitter_move_sheet.png', 4, None, 0, 24, 18),
    ('spitter_attack', 'spitter_attack_sheet.png', 4, None, 0, 24, 18),
]
# 参照の絵がない（スライム）ものは、立ち姿の高さを決めておく
SLIME_HEIGHT = 9  # いまのスライムの絵（Enemy._make_figure）の高さ（ドット）


def key_green(im):
    a = np.asarray(im.convert('RGB')).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # 背景の緑 #00ff00 だけを抜く（スライムの黄緑の縁 (155,232,96) は残す）
    green = (g > 180) & (r < 90) & (b < 90)
    alpha = np.where(green, 0, 255).astype(np.uint8)
    return np.dstack([a.astype(np.uint8), alpha])


def bbox(rgba):
    ys, xs = np.where(rgba[..., 3] > 0)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def feet_center(rgba):
    x0, y0, x1, y1 = bbox(rgba)
    top = y1 - max(1, int((y1 - y0) * 0.1))
    ys, xs = np.where(rgba[top:y1, :, 3] > 0)
    return float(xs.mean())


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


only = sys.argv[1:]
for name, sheet_name, frames, ref_name, base, out_w, out_h in SPECS:
    path = os.path.join(here, 'source', 'anim', sheet_name)
    if not os.path.exists(path) or (only and name not in only):
        continue
    sheet = Image.open(path).convert('RGB')
    cell_w = sheet.width // frames
    cells = [key_green(sheet.crop((i * cell_w, 0, (i + 1) * cell_w, sheet.height))) for i in range(frames)]
    if ref_name:
        ref = np.asarray(Image.open(os.path.join(here, ref_name)).convert('RGBA'))
        _, ry0, _, ry1 = bbox(ref)
        target_h = ry1 - ry0
    else:
        target_h = SLIME_HEIGHT
    sx0, sy0, sx1, sy1 = bbox(cells[base])
    src_h = sy1 - sy0
    win_h = int(round(src_h * out_h / float(target_h)))
    win_w = int(round(src_h * out_w / float(target_h)))
    fx = feet_center(cells[base])
    wx0 = int(round(fx - win_w * 0.5))
    wy0 = int(round(sy1 - win_h))  # 窓の下の端＝足元
    for i, cell in enumerate(cells):
        h, w = cell.shape[:2]
        canvas = np.zeros((win_h, win_w, 4), dtype=np.uint8)
        x0, y0 = max(wx0, 0), max(wy0, 0)
        x1, y1 = min(wx0 + win_w, w), min(wy0 + win_h, h)
        canvas[y0 - wy0:y1 - wy0, x0 - wx0:x1 - wx0] = cell[y0:y1, x0:x1]
        shrink(canvas, (out_w, out_h)).save(os.path.join(here, '%s_%d.png' % (name, i)))
    print(name, 'window', win_w, win_h, 'target_h', target_h, 'src_h', src_h)
print('ok')
