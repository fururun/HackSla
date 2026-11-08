# プレイヤー（ポニーテールの侍・羽織）のドット絵を作る。python art/sprites/player/make_player.py
# 参考画像：黒髪ポニーテール、青緑の羽織（白い柄）、黒い袴に赤い帯、刀。16x24。
import zlib, struct, sys, os

PAL = {
    '.': None,
    'K': (0x1b, 0x14, 0x22),   # 輪郭
    'H': (0x2f, 0x26, 0x3a),   # 髪
    'h': (0x5d, 0x4c, 0x6e),   # 髪の光
    'S': (0xf2, 0xd2, 0xaa),   # 肌
    's': (0xd8, 0xa9, 0x82),   # 肌の影
    'E': (0x2a, 0x20, 0x30),   # 目
    'T': (0x2f, 0x93, 0x9d),   # 羽織
    't': (0x1f, 0x66, 0x72),   # 羽織の影
    'W': (0xf0, 0xe8, 0xd2),   # 白・柄・帯
    'w': (0xc8, 0xbc, 0x9e),   # 白の影
    'R': (0xb0, 0x33, 0x30),   # 赤
    'r': (0x72, 0x20, 0x24),   # 赤の影
    'B': (0x2d, 0x26, 0x3c),   # 袴
    'b': (0x4a, 0x40, 0x5c),   # 袴の光
    'G': (0xdc, 0xa8, 0x3c),   # 金具
    'L': (0x5e, 0x40, 0x2c),   # すね当て
    'X': (0xf6, 0xf6, 0xfb),   # 刀身
    'x': (0xa9, 0xb3, 0xc4),   # 刀身の影
}

FRONT = [
"................",
"......KKK.KK....",
".....KHHHKHHK...",
"....KHHhHHHHHK..",
"...KHHHHHHHHKHK.",
"...KHHHHHHHHHKHK",
"..KHHSSSSSSHHKHK",
"..KHSSSSSSSSHKHK",
"..KHSEESSEESHKK.",
"..KHSEESSEESHK..",
"...KSSSSSSSSK...",
"....KKSSSSKK....",
"...KTTTWWTTTK...",
"..KTTTWRRWTTTK..",
".KTWTTWRRWTTWTK.",
".KTWWTKWWKTWWTK.",
".XKTTTKRRKTTTKG.",
"..xKTKBRRBKTKG..",
"...KKBBBBBBKK...",
"...KBBbBBbBBK...",
"...KBBB..BBBK...",
"...KLLK..KLLK...",
"...KGGK..KGGK...",
"...KKKK..KKKK...",
]

BACK = [
"................",
"........KKK.....",
".....KKKHHHK....",
"....KHHHhHHHK...",
"...KHHHHHHHHK...",
"...KHHHHHHHHHK..",
"..KHHHHHHHHHHK..",
"..KHHHHHhHHHHK..",
"..KHHHHHHHHHHK..",
"..KHHHHHHHHHHK..",
"...KHHHHHHHHK...",
"....KKHHHHKK....",
"...KTTTTTTTTK...",
"..KTTTTTTTTTTK..",
".KTWTTTTTTTTWTK.",
".KTWWTTTTTTWWTK.",
".GKTTTTWWTTTTK..",
"..GKTTTWWTTTK...",
"...KKBBBBBBKK...",
"...KBBbBBbBBK...",
"...KBBB..BBBK...",
"...KLLK..KLLK...",
"...KGGK..KGGK...",
"...KKKK..KKKK...",
]

SIDE = [  # 右向き
"................",
"....KKK.KK......",
"...KHHHKHHK.....",
"..KHHHHHHHHK....",
"..KHHHHHHHHHK...",
".KHHHHHHHHHHHK..",
".KHHHSSSSSHHHK..",
".KHHSSSSSSSHHK..",
".KHKSSSEESSSHK..",
"..KHSSSEESSSKHK.",
"..KHSSSSSSSK.KK.",
"...KKSSSSKK.....",
"...KTTTWWTTK....",
"..KTTTWRRWTTK...",
"..KTWTWRRWTWK...",
"..KTWWKRRKWWK.X.",
"..KTTTKRRKTTKxX.",
"...KTTBRRBTKGx..",
"...KKBBBBBKK....",
"...KBBbBBBBK....",
"...KBBBBBBBK....",
"...KLLKKKLLK....",
"...KGGK.KGGK....",
"...KKKK.KKKK....",
]

def write_png(path, rows):
    h = len(rows); w = len(rows[0])
    raw = bytearray()
    for r in rows:
        assert len(r) == w, (len(r), w, r)
        raw.append(0)
        for ch in r:
            c = PAL[ch]
            raw += bytes(c + (255,)) if c else bytes((0, 0, 0, 0))
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)

def pad(rows, n=2):
    return [('.' * n) + r + ('.' * n) for r in rows]

def put(rows, pts, ch):
    rows = [list(r) for r in rows]
    for (r, c) in pts:
        rows[r][c] = ch
    return [''.join(r) for r in rows]

# 刀・ポニーテールを足すために左右に2マス広げる（20x24）
FRONT = pad(FRONT); BACK = pad(BACK); SIDE = pad(SIDE, 2)
# 前：ポニーテール（右の肩へ流れる）と、左手の刀（切っ先が左下）
FRONT = put(FRONT, [(2,15),(2,16),(3,16),(3,17),(4,17),(4,18),(5,17),(5,18),(6,18),(7,18),(8,18),(9,17),(9,18),(10,17)], 'H')
FRONT = put(FRONT, [(3,17),(5,18),(8,18)], 'h')
FRONT = put(FRONT, [(16,3),(17,2),(18,1),(19,0)], 'X')
FRONT = put(FRONT, [(17,3)], 'G')
# 後ろ：ポニーテールが背中側に垂れる
BACK = put(BACK, [(10,9),(10,10),(11,9),(11,10),(12,9),(12,10),(13,9),(13,10),(14,9),(14,10),(15,10)], 'H')
BACK = put(BACK, [(11,9),(13,10)], 'h')
# 横：ポニーテールが後ろ（左）になびく
SIDE = put(SIDE, [(3,2),(4,1),(5,0),(6,0),(7,1),(8,1),(9,2)], 'H')
SIDE = put(SIDE, [(5,0),(7,1)], 'h')
# 横：刀を前に構える
SIDE = put(SIDE, [(15,16),(14,17),(13,18),(12,19)], 'X')

here = os.path.dirname(os.path.abspath(__file__))
for name, rows in (('front', FRONT), ('back', BACK), ('side', SIDE)):
    write_png(os.path.join(here, 'player_%s.png' % name), rows)
    big = [''.join(ch * 10 for ch in r) for r in rows for _ in range(10)]
    write_png(os.path.join(here, 'preview_%s.png' % name), big)
print('ok')
