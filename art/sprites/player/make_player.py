# プレイヤー（ポニーテールの侍）のドット絵を作る。  python art/sprites/player/make_player.py
# キャラクター：黒髪の高いポニーテールの侍。青緑の羽織（袖と裾に白い柄）、黒い胴当てと金の紋、白い帯、
#               赤い前掛け付きの黒い袴、金の縁のすね当て、白足袋、左手に抜いた刀、右の腰に鞘。
# ドット絵の雰囲気：2頭身にデフォルメ、大きな目、全体に陰影、外側に1ドットの暗い輪郭線。
# 点・四角・楕円・線・多角形を重ねて描き、最後に輪郭を自動でつける。36x36、足元の中心が (17.5, 35)。
import zlib, struct, os, math

W, H = 36, 36
PAL = {
    'K': (0x1b, 0x14, 0x22),                                                       # 輪郭
    'H': (0x2f, 0x26, 0x3a), 'h': (0x5d, 0x4c, 0x6e), 'I': (0x88, 0x78, 0xa0),     # 黒髪・光・強い光
    'k': (0xf7, 0xd9, 0xc4), 'q': (0xe2, 0xaa, 0x8c),                              # 肌・影
    'E': (0x2a, 0x20, 0x30), 'F': (0xff, 0xff, 0xff), 'e': (0x5a, 0x4a, 0x70),     # 目・光・虹彩
    'T': (0x2f, 0x93, 0x9d), 't': (0x1f, 0x66, 0x72), 'U': (0x55, 0xb9, 0xbf),     # 羽織・影・光
    'W': (0xf0, 0xe8, 0xd2), 'w': (0xc8, 0xbc, 0x9e),                              # 白・影
    'R': (0xb0, 0x33, 0x30), 'r': (0x72, 0x20, 0x24), 'o': (0xd8, 0x55, 0x50),     # 赤・影・光
    'B': (0x2d, 0x26, 0x3c), 'b': (0x4a, 0x40, 0x5c),                              # 黒（袴・胴当て）・光
    'G': (0xdc, 0xa8, 0x3c), 'g': (0x8a, 0x62, 0x1c), 'Y': (0xf6, 0xd8, 0x84),     # 金・影・光
    'L': (0x5e, 0x40, 0x2c),                                                       # すね当て
    'X': (0xf6, 0xf6, 0xfb), 'x': (0xa9, 0xb3, 0xc4),                              # 刀身・影
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


def hakama(i, panel=True):
    # 袴（黒）、赤い前掛け、金の縁のすね当て、白足袋と赤い鼻緒
    i.poly([(11, 25), (24, 25), (26, 31), (9, 31)], 'B')
    i.line(13, 26, 11, 31, 'b')
    i.line(22, 26, 24, 31, 'b')
    if panel:
        i.rect(15, 24, 20, 31, 'R')
        i.rect(15, 24, 15, 31, 'r')
        i.rect(20, 24, 20, 31, 'r')
        for y in (26, 28, 30):
            i.line(15, y, 20, y, 'r')
        i.line(17, 25, 17, 30, 'o')
    i.rect(12, 31, 16, 33, 'L')
    i.rect(19, 31, 23, 33, 'L')
    i.rect(12, 31, 16, 31, 'G')
    i.rect(19, 31, 23, 31, 'G')
    i.rect(12, 34, 16, 35, 'W')
    i.rect(19, 34, 23, 35, 'W')
    i.rect(12, 34, 13, 34, 'R')
    i.rect(22, 34, 23, 34, 'R')


def haori(i, back=False):
    # 羽織（青緑）、袖、白いぎざぎざの柄
    i.poly([(9, 17), (26, 17), (27, 26), (8, 26)], 'T')
    i.poly([(3, 18), (10, 17), (10, 26), (4, 25)], 'T')
    i.poly([(25, 17), (32, 18), (31, 25), (25, 26)], 'T')
    i.poly([(3, 21), (5, 23), (7, 21), (10, 23), (10, 26), (4, 25)], 'W')
    i.poly([(32, 21), (30, 23), (28, 21), (25, 23), (25, 26), (31, 25)], 'W')
    i.poly([(8, 24), (11, 26), (14, 24), (17, 26), (20, 24), (23, 26), (26, 24), (27, 26), (8, 26)], 'W')
    i.rect(8, 17, 10, 24, 't')
    i.rect(25, 17, 27, 24, 't')
    i.line(4, 19, 9, 18, 'U')
    i.line(26, 18, 31, 19, 'U')
    i.line(10, 20, 10, 24, 'T')
    i.line(25, 20, 25, 24, 'T')
    i.rect(10, 24, 25, 25, 'W')       # 白い帯
    i.line(10, 25, 25, 25, 'w')


def front():
    i = Img()
    # ポニーテール（高い位置で結んで、右へ大きく流れる）
    i.poly([(21, 3), (27, 0), (33, 3), (35, 9), (34, 16), (31, 22), (28, 18), (30, 12), (27, 8), (23, 7)], 'H')
    i.line(26, 2, 32, 5, 'h')
    i.line(30, 5, 34, 10, 'h')
    i.line(33, 12, 31, 20, 'h')
    i.line(31, 6, 33, 8, 'I')
    i.rect(20, 3, 23, 5, 'G')
    i.rect(21, 3, 22, 3, 'Y')
    hakama(i)
    haori(i)
    # 胴当て（黒、金の紋）と襟
    i.rect(14, 18, 21, 23, 'B')
    i.rect(15, 18, 15, 23, 'b')
    i.rect(16, 19, 19, 21, 'G')
    i.rect(17, 19, 18, 20, 'B')
    i.rect(16, 19, 17, 19, 'Y')
    i.rect(13, 16, 22, 17, 'W')
    i.line(13, 17, 22, 17, 'w')
    # 首と頭
    i.rect(15, 15, 20, 16, 'q')
    i.ell(17.5, 9, 10.5, 9, 'H')
    i.ell(17.5, 11, 7.5, 6.5, 'k')
    i.ell(17.5, 6, 9.5, 5, 'H')
    for x, d in ((9, 5), (11, 4), (13, 5), (15, 4), (19, 4), (21, 5), (23, 4), (25, 5)):
        i.rect(x, 6, x + 1, 6 + d, 'H')
    i.rect(7, 8, 9, 16, 'H')
    i.rect(26, 8, 28, 16, 'H')
    i.line(11, 3, 24, 3, 'h')
    i.line(9, 6, 13, 4, 'h')
    i.line(22, 4, 26, 6, 'h')
    i.line(14, 4, 18, 4, 'I')
    i.line(8, 10, 8, 15, 'h')
    i.line(27, 10, 27, 15, 'h')
    # 顔：大きなつり目（虹彩と光）、眉、口
    for ex in (11, 20):
        i.rect(ex, 11, ex + 3, 13, 'E')
        i.rect(ex + 1, 12, ex + 2, 13, 'e')
        i.put(ex, 11, 'F')
        i.put(ex + 1, 11, 'F')
        i.put(ex + 3, 13, 'F')
        i.line(ex - 1, 10, ex + 4, 10, 'K')
    i.line(10, 9, 14, 10, 'K')
    i.line(21, 10, 25, 9, 'K')
    i.put(17, 15, 'q')
    i.put(18, 15, 'q')
    i.put(15, 14, 'q')
    i.put(20, 14, 'q')
    # 刀（左手＝画面左、切っ先が下）と鞘（右の腰）
    i.line(6, 23, 0, 33, 'X', 2)
    i.line(7, 23, 1, 34, 'x')
    i.rect(3, 20, 8, 21, 'G')
    i.rect(4, 15, 6, 20, 'B')
    i.line(4, 16, 6, 18, 'b')
    i.rect(3, 22, 7, 24, 'k')
    i.line(24, 23, 32, 28, 'B', 2)
    i.line(24, 24, 32, 29, 'b')
    i.rect(31, 28, 33, 30, 'G')
    i.outline()
    return i


def back():
    i = Img()
    hakama(i, panel=False)
    haori(i, back=True)
    # 背中の白い柄
    i.poly([(13, 18), (17, 24), (13, 24)], 'W')
    i.poly([(22, 18), (18, 24), (22, 24)], 'W')
    i.rect(15, 15, 20, 16, 'q')
    # 髪：後ろ姿はすべて黒髪、結び目と、背中へ垂れるポニーテール
    i.ell(17.5, 9, 10.5, 10, 'H')
    i.rect(7, 7, 28, 16, 'H')
    i.rect(15, 0, 20, 4, 'H')
    i.rect(15, 3, 20, 5, 'G')
    i.rect(16, 3, 17, 3, 'Y')
    i.poly([(13, 6), (22, 6), (24, 14), (22, 22), (19, 29), (16, 22), (13, 14)], 'H')
    i.line(18, 7, 19, 16, 'h')
    i.line(17, 17, 18, 26, 'h')
    i.line(11, 8, 15, 5, 'h')
    i.line(9, 10, 9, 15, 'h')
    i.line(26, 10, 26, 15, 'h')
    i.line(10, 16, 25, 16, 'b')
    # 腰の鞘
    i.line(24, 23, 32, 28, 'B', 2)
    i.rect(31, 28, 33, 30, 'G')
    i.outline()
    return i


def side():
    i = Img()
    # 右向き。ポニーテールは後ろ（左）へなびき、刀は前へ構える
    i.poly([(14, 3), (8, 0), (2, 3), (0, 9), (1, 16), (4, 22), (7, 18), (5, 12), (8, 8), (12, 7)], 'H')
    i.line(9, 2, 3, 5, 'h')
    i.line(5, 5, 1, 10, 'h')
    i.line(2, 12, 4, 20, 'h')
    i.rect(12, 3, 15, 5, 'G')
    hakama(i, panel=False)
    i.rect(14, 24, 20, 31, 'R')
    i.rect(14, 24, 14, 31, 'r')
    for y in (26, 28, 30):
        i.line(14, y, 20, y, 'r')
    # 羽織（横から）と袖
    i.poly([(9, 17), (24, 17), (25, 26), (9, 26)], 'T')
    i.rect(9, 17, 11, 25, 't')
    i.poly([(9, 24), (12, 26), (15, 24), (18, 26), (21, 24), (24, 26), (9, 26)], 'W')
    i.rect(10, 24, 24, 25, 'W')
    i.poly([(13, 18), (21, 18), (22, 24), (13, 24)], 'W')
    i.rect(14, 18, 20, 23, 'B')
    i.rect(16, 19, 19, 21, 'G')
    i.rect(13, 16, 21, 17, 'W')
    i.rect(15, 15, 20, 16, 'q')
    # 頭（右向きの横顔）
    i.ell(16.5, 9, 9.5, 9, 'H')
    i.ell(19.5, 11, 6.5, 6, 'k')
    i.ell(16.5, 6, 9.5, 5, 'H')
    for x, d in ((15, 5), (17, 4), (19, 5), (21, 4), (23, 4)):
        i.rect(x, 6, x + 1, 6 + d, 'H')
    i.rect(8, 8, 13, 16, 'H')
    i.line(11, 3, 23, 3, 'h')
    i.line(9, 10, 9, 15, 'h')
    i.rect(21, 11, 24, 13, 'E')
    i.rect(22, 12, 23, 13, 'e')
    i.put(21, 11, 'F')
    i.put(22, 11, 'F')
    i.line(20, 10, 25, 10, 'K')
    i.line(22, 9, 26, 10, 'K')
    i.put(25, 15, 'q')
    # 前へ構えた刀
    i.line(22, 22, 34, 14, 'X', 2)
    i.line(22, 23, 34, 15, 'x')
    i.rect(18, 20, 22, 23, 'G')
    i.rect(16, 21, 18, 22, 'B')
    i.rect(18, 23, 22, 25, 'k')
    i.outline()
    return i


here = os.path.dirname(os.path.abspath(__file__))
for name, fn in (('front', front), ('back', back), ('side', side)):
    img = fn()
    save(img, os.path.join(here, 'player_proc_%s.png' % name))
    save(img, os.path.join(here, 'preview_proc_%s.png' % name), 8)
print('ok', W, H)
