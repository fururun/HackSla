# プレイヤー（角と銀髪ツインテール・赤い目・紺のレオタード・赤いコート・竜の尻尾・金の長柄武器）のドット絵を作る。
#   python art/sprites/player/make_player.py
# 参考画像：銀髪のツインテール、黒紫の角、赤橙の目、紺のレオタードに赤いコート、素足に紺の靴、
# 背中の赤い小さな翼、赤黒い竜の尻尾、金の穂先と三日月の刃の長柄武器。
# 点・四角・楕円・線・多角形を重ねて描き、最後に外側へ1ドットの暗い輪郭を自動でつける。36x36、足元の中心が (17.5, 35)。
import zlib, struct, os, math

W, H = 36, 36
PAL = {
    'K': (0x1b, 0x14, 0x22),                                  # 輪郭
    'W': (0xe8, 0xeb, 0xf3), 'z': (0xb6, 0xbc, 0xd0), 'Z': (0x8a, 0x91, 0xaa),   # 銀髪・影・深い影
    'D': (0x3a, 0x2a, 0x46), 'd': (0x74, 0x52, 0x7c),          # 角・光る筋
    'k': (0xf7, 0xd9, 0xc4), 'q': (0xe2, 0xaa, 0x8c),          # 肌・影
    'O': (0xe9, 0x4a, 0x1e), 'F': (0xff, 0xff, 0xff), 'E': (0x40, 0x14, 0x14),   # 目
    'N': (0x2b, 0x30, 0x52), 'n': (0x44, 0x4d, 0x7e),          # 紺（レオタード・靴）
    'R': (0xc1, 0x30, 0x3a), 'r': (0x7a, 0x1d, 0x2a), 'o': (0xe0, 0x58, 0x55),   # 赤（コート・翼）
    'P': (0x3a, 0x3a, 0x6c),                                   # 籠手・足首の帯
    'G': (0xd9, 0xa6, 0x3c), 'Y': (0xf6, 0xd8, 0x84), 'g': (0x8a, 0x62, 0x1c),   # 金
    'T': (0x9a, 0x2e, 0x32), 't': (0x5e, 0x1a, 0x22),          # 尻尾
}


class Img:
    def __init__(self):
        self.p = [[None] * W for _ in range(H)]

    def put(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.p[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def ell(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c, w=1):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            for k in range(w):
                self.put(x, y + k, c)

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(min(ys), max(ys) + 1):
            xs = []
            for i in range(len(pts)):
                (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % len(pts)]
                if (ya <= y < yb) or (yb <= y < ya):
                    xs.append(xa + (y - ya) * (xb - xa) / (yb - ya))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(math.ceil(xs[i]), math.floor(xs[i + 1]) + 1):
                    self.put(x, y, c)

    def outline(self):
        q = [row[:] for row in self.p]
        for y in range(H):
            for x in range(W):
                if self.p[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < W and 0 <= ny < H and self.p[ny][nx] not in (None, 'K'):
                            q[y][x] = 'K'
                            break
        self.p = q


def save(img, path, scale=1):
    raw = bytearray()
    for y in range(H * scale):
        raw.append(0)
        for x in range(W * scale):
            c = img.p[y // scale][x // scale]
            raw += bytes(PAL[c] + (255,)) if c else bytes((0, 0, 0, 0))

    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)

    data = (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', W * scale, H * scale, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
            + chunk(b'IEND', b''))
    open(path, 'wb').write(data)


def tail(i, mirror=False):
    # 腰から出て、右下へ大きく曲がる竜の尻尾（先は矢じり形）。mirror で左右反転
    m = (lambda x: 35 - x) if mirror else (lambda x: x)
    pts = [(21, 27), (25, 29), (29, 31), (32, 30), (33, 27), (32, 24)]
    for k in range(len(pts) - 1):
        (xa, ya), (xb, yb) = pts[k], pts[k + 1]
        w = 3 if k < 3 else 2
        i.line(m(xa), ya, m(xb), yb, 'T', w)
    i.line(m(22), 28, m(30), 32, 't')
    i.poly([(m(31), 24), (m(34), 21), (m(35), 25), (m(33), 26)], 'T')
    i.put(m(34), 23, 't')


def spear(i, flip=False):
    # 金の長柄武器：左下に穂先、右上に三日月の刃。flip で左右反転
    m = (lambda x: 35 - x) if flip else (lambda x: x)
    i.line(m(4), 29, m(29), 5, 'G', 2)
    i.line(m(5), 29, m(30), 6, 'g')
    i.line(m(14), 21, m(16), 19, 'R', 2)   # 赤い帯
    i.poly([(m(0), 31), (m(5), 27), (m(7), 29), (m(3), 33)], 'Y')
    i.line(m(1), 31, m(5), 28, 'G')
    i.poly([(m(27), 3), (m(33), 0), (m(35), 5), (m(33), 11), (m(31), 8), (m(32), 5)], 'G')
    i.poly([(m(29), 4), (m(33), 2), (m(33), 5)], 'Y')
    i.rect(m(27), 4, m(28), 7, 'g')


def front():
    i = Img()
    tail(i)
    spear(i)
    # 背中の小さな翼
    i.poly([(23, 17), (31, 13), (30, 19), (26, 22)], 'R')
    i.poly([(12, 17), (5, 14), (6, 19), (10, 22)], 'r')
    i.line(24, 17, 30, 14, 'o')
    # 脚（素足）と靴
    i.rect(13, 27, 16, 32, 'k')
    i.rect(19, 27, 22, 32, 'k')
    i.rect(13, 27, 13, 32, 'q')
    i.rect(19, 27, 19, 32, 'q')
    i.rect(13, 32, 16, 32, 'P')
    i.rect(19, 32, 22, 32, 'P')
    i.rect(12, 33, 16, 35, 'N')
    i.rect(19, 33, 23, 35, 'N')
    i.line(12, 34, 16, 34, 'n')
    i.line(19, 34, 23, 34, 'n')
    # コート（赤）：腰から裾が広がる
    i.poly([(8, 17), (13, 17), (13, 25), (11, 30), (5, 29), (6, 23)], 'R')
    i.poly([(22, 17), (27, 17), (29, 23), (30, 29), (24, 30), (22, 25)], 'R')
    i.line(6, 24, 11, 29, 'r')
    i.line(29, 24, 25, 29, 'r')
    i.line(5, 29, 11, 30, 'r')
    i.line(24, 30, 30, 29, 'r')
    i.rect(8, 17, 9, 24, 'o')
    # 胴（紺のレオタード）と金の襟飾り
    i.poly([(13, 18), (22, 18), (22, 24), (23, 27), (12, 27), (13, 24)], 'N')
    i.line(14, 19, 14, 25, 'n')
    i.rect(14, 17, 21, 18, 'G')
    i.rect(16, 19, 19, 20, 'g')
    i.rect(17, 19, 18, 19, 'Y')
    # 腕（素肌）と籠手
    i.rect(10, 18, 12, 22, 'k')
    i.rect(23, 18, 25, 22, 'k')
    i.rect(9, 22, 12, 24, 'P')
    i.rect(23, 22, 26, 24, 'P')
    # ツインテール（銀髪）
    i.poly([(25, 8), (31, 10), (32, 17), (30, 23), (27, 19), (28, 13)], 'W')
    i.poly([(10, 8), (4, 10), (3, 17), (5, 23), (8, 19), (7, 13)], 'W')
    i.line(30, 11, 31, 18, 'z')
    i.line(5, 11, 4, 18, 'z')
    i.line(29, 20, 29, 22, 'Z')
    i.line(6, 20, 6, 22, 'Z')
    # 頭：髪の土台・顔・前髪
    i.ell(17.5, 10, 10, 9, 'W')
    i.ell(17.5, 12, 7, 6, 'k')
    i.ell(17.5, 7, 9, 5, 'W')
    for x, d in ((10, 4), (12, 3), (14, 4), (16, 3), (19, 3), (21, 4), (23, 3)):
        i.rect(x, 7, x + 1, 7 + d, 'W')
    i.rect(8, 8, 10, 15, 'W')
    i.rect(25, 8, 27, 15, 'W')
    i.line(11, 4, 24, 4, 'z')
    i.line(9, 7, 12, 5, 'z')
    i.line(23, 5, 26, 7, 'z')
    # 角（黒紫）
    i.poly([(9, 7), (5, 4), (5, 0), (10, 2), (12, 7)], 'D')
    i.poly([(26, 7), (30, 4), (30, 0), (25, 2), (23, 7)], 'D')
    i.line(6, 2, 10, 4, 'd')
    i.line(29, 2, 25, 4, 'd')
    # 顔：大きな赤橙の目、口
    for ex in (11, 20):
        i.rect(ex, 12, ex + 3, 14, 'O')
        i.rect(ex + 1, 13, ex + 2, 14, 'E')
        i.put(ex, 12, 'F')
        i.put(ex + 1, 12, 'F')
        i.line(ex - 1, 11, ex + 4, 11, 'K')
    i.put(17, 16, 'q')
    i.put(18, 16, 'q')
    i.outline()
    return i


def back():
    i = Img()
    tail(i, mirror=True)
    spear(i, flip=True)
    # 脚と靴
    i.rect(13, 27, 16, 32, 'k')
    i.rect(19, 27, 22, 32, 'k')
    i.rect(13, 32, 16, 32, 'P')
    i.rect(19, 32, 22, 32, 'P')
    i.rect(12, 33, 16, 35, 'N')
    i.rect(19, 33, 23, 35, 'N')
    # 赤いコートの背中と翼
    i.poly([(8, 17), (27, 17), (30, 29), (24, 30), (17, 28), (11, 30), (5, 29)], 'R')
    i.line(17, 20, 17, 28, 'r')
    i.line(5, 29, 11, 30, 'r')
    i.line(24, 30, 30, 29, 'r')
    i.poly([(23, 15), (31, 11), (30, 17), (26, 20)], 'R')
    i.poly([(12, 15), (4, 11), (5, 17), (9, 20)], 'r')
    i.rect(14, 17, 21, 18, 'G')
    i.rect(10, 18, 12, 24, 'k')
    i.rect(23, 18, 25, 24, 'k')
    i.rect(9, 22, 12, 24, 'P')
    i.rect(23, 22, 26, 24, 'P')
    # 髪：後ろ姿はすべて銀髪、ツインテールが肩へ垂れる
    i.poly([(25, 8), (31, 10), (32, 18), (30, 24), (27, 20), (28, 13)], 'W')
    i.poly([(10, 8), (4, 10), (3, 18), (5, 24), (8, 20), (7, 13)], 'W')
    i.ell(17.5, 10, 10, 10, 'W')
    i.rect(8, 8, 27, 18, 'W')
    i.line(11, 4, 24, 4, 'z')
    i.line(17, 6, 17, 17, 'z')
    i.line(30, 11, 31, 19, 'z')
    i.line(5, 11, 4, 19, 'z')
    i.line(9, 16, 26, 16, 'Z')
    i.poly([(9, 7), (5, 4), (5, 0), (10, 2), (12, 7)], 'D')
    i.poly([(26, 7), (30, 4), (30, 0), (25, 2), (23, 7)], 'D')
    i.line(6, 2, 10, 4, 'd')
    i.line(29, 2, 25, 4, 'd')
    i.outline()
    return i


def side():
    i = Img()
    # 右向き。尻尾は後ろ（左）へ、長柄武器は前へ
    tail(i, mirror=True)
    i.line(14, 24, 33, 8, 'G', 2)
    i.line(15, 24, 34, 9, 'g')
    i.line(12, 25, 15, 22, 'R', 2)
    i.poly([(28, 4), (33, 0), (35, 5), (33, 10), (31, 7), (32, 5)], 'G')
    i.poly([(30, 4), (33, 2), (33, 5)], 'Y')
    i.poly([(10, 27), (14, 22), (16, 24), (12, 29)], 'Y')
    i.poly([(11, 17), (5, 14), (6, 20), (10, 22)], 'R')
    # 脚と靴
    i.rect(14, 27, 17, 32, 'k')
    i.rect(18, 27, 21, 32, 'k')
    i.rect(14, 32, 17, 32, 'P')
    i.rect(18, 32, 21, 32, 'P')
    i.rect(14, 33, 19, 35, 'N')
    i.rect(18, 33, 23, 35, 'N')
    # コートと胴
    i.poly([(11, 17), (23, 17), (25, 29), (11, 30), (9, 24)], 'R')
    i.line(9, 24, 11, 30, 'r')
    i.line(11, 30, 25, 29, 'r')
    i.poly([(14, 18), (22, 18), (22, 27), (13, 27)], 'N')
    i.rect(14, 17, 21, 18, 'G')
    i.rect(18, 19, 21, 21, 'g')
    i.rect(19, 18, 22, 23, 'k')
    i.rect(18, 22, 22, 24, 'P')
    # 髪（ツインテールが後ろにたなびく）
    i.poly([(11, 8), (5, 11), (3, 18), (5, 24), (9, 20), (9, 13)], 'W')
    i.line(5, 12, 4, 19, 'z')
    i.ell(16.5, 10, 9, 9, 'W')
    i.ell(19, 12, 6.5, 6, 'k')
    i.ell(16, 7, 9, 5, 'W')
    for x, d in ((15, 4), (17, 3), (19, 4), (21, 3), (23, 3)):
        i.rect(x, 7, x + 1, 7 + d, 'W')
    i.rect(10, 8, 14, 16, 'W')
    i.line(11, 4, 22, 4, 'z')
    i.poly([(14, 6), (10, 3), (10, 0), (15, 1), (17, 6)], 'D')
    i.line(11, 1, 15, 3, 'd')
    i.rect(21, 12, 24, 14, 'O')
    i.rect(22, 13, 23, 14, 'E')
    i.put(21, 12, 'F')
    i.put(22, 12, 'F')
    i.line(20, 11, 25, 11, 'K')
    i.put(25, 16, 'q')
    i.outline()
    return i


here = os.path.dirname(os.path.abspath(__file__))
for name, fn in (('front', front), ('back', back), ('side', side)):
    img = fn()
    save(img, os.path.join(here, 'player_%s.png' % name))
    save(img, os.path.join(here, 'preview_%s.png' % name), 8)
print('ok', W, H)
