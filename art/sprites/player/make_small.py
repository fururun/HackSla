# 高解像度の侍の絵（player_hi_*.png、96x96）を、ゲームで使う大きさに縮めて player_*.png に書き出す。
#   python art/sprites/player/make_small.py        （既定 30）
#   python art/sprites/player/make_small.py 36     （大きさを変えたいとき。数字は1辺のドット数）
# 縮め方：透明部分の色が混ざらないようアルファ付きで平均し、縁は半透明にせず（アルファ0.45以上で不透明）、ドット絵の輪郭を保つ。
# 大きさを変えたら、scripts/player/player.gd の SPRITE_SIZE も同じ数字に合わせる。
import os, sys
import numpy as np
from PIL import Image

SIZE = int(sys.argv[1]) if len(sys.argv) > 1 else 30
here = os.path.dirname(os.path.abspath(__file__))

for name in ('front', 'back', 'side'):
    im = Image.open(os.path.join(here, 'player_hi_%s.png' % name)).convert('RGBA')
    a = np.asarray(im).astype(np.float32) / 255.0
    pm = a.copy()
    pm[..., :3] *= a[..., 3:4]
    chans = [np.asarray(Image.fromarray((pm[..., c] * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.BOX)) for c in range(4)]
    small = np.stack(chans, -1).astype(np.float32) / 255.0
    al = small[..., 3:4]
    rgb = np.where(al > 0.01, small[..., :3] / np.maximum(al, 1e-4), 0)
    out = np.concatenate([np.clip(rgb, 0, 1), (al > 0.45).astype(np.float32)], -1)
    Image.fromarray((out * 255).round().astype(np.uint8), 'RGBA').save(os.path.join(here, 'player_%s.png' % name))
print('ok', SIZE)
