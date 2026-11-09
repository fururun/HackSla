# 広いマップ data/maps/field_01.txt を作る。  python tools/maps/make_field_01.py
# 「廃寺の地下墓所」の構成：参道 → 山門 → 境内（中庭）を中心に、道が分かれ、ぐるっと回れる（周回）。
#   ・回廊の環：境内の南に、本堂（中に小部屋）をぐるりと囲む環状の廊下
#   ・周回1：開始の広場 → 僧坊 → 回廊 → 境内 → 山門 → 開始の広場
#   ・周回2：境内 → 鐘楼 → 墓所 → 回廊 → 境内
#   ・周回3：回廊 → 墓所 → 奥の広間 → 回廊
#   ・ボスの部屋（奥の院）には、奥の広間を抜けた先でしか入れない（道は1本）
# 印の数は前と同じ（P1 D2 C5 L4 f4 s7 b3 r5 X1）。経験値の見積もりは docs/map_field_01.md。
#
# 印：  # 壁   . 床   P 開始位置   D 案山子   C 宝箱
#       L レジェンドの宝箱の候補（超低確率で、1か所に出る）
#       f 小さなスライムの群れ(5匹)   s スライムの群れ(8〜14匹)   b 岩殻(1体)   r 遠くから撃つスライム   X ボス(岩殻の主)
import os

W, H = 74, 52
g = [['#'] * W for _ in range(H)]


def carve(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = '.'


def fill(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = '#'


def carve_oct(x0, y0, x1, y1, cut):
    """四角の四隅を、斜めに cut マス分だけ落とした八角形"""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if min(x - x0 + y - y0, x1 - x + y - y0, x - x0 + y1 - y, x1 - x + y1 - y) >= cut:
                g[y][x] = '.'


def carve_ellipse(x0, y0, x1, y1):
    """四角に内接する楕円（丸い広場）"""
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    rx, ry = (x1 - x0 + 1) / 2.0, (y1 - y0 + 1) / 2.0
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                g[y][x] = '.'


def pillar(x, y):
    """床の中に柱（壁）を立てる。印や通路の入口には立てない"""
    assert g[y][x] == '.', (x, y)
    g[y][x] = '#'


def mark(x, y, c):
    assert g[y][x] == '.', (x, y, c)
    g[y][x] = c


# ---- 部屋 ----
# 開始の広場（参道の入口。安全。案山子と宝箱）
carve_oct(2, 2, 14, 12, 3)
# 山門（小さな門の間）
carve_oct(24, 3, 30, 10, 2)
# 境内（中庭。大きな広場）
carve_oct(31, 2, 57, 20, 4)
# 鐘楼（北東の小部屋）
carve_oct(63, 3, 71, 13, 2)
# 僧坊（西の部屋）
carve_oct(2, 24, 14, 35, 2)
# 回廊の環：外側を八角形に彫り、内側を壁の塊（本堂）にして、廊下の環にする
carve_oct(27, 27, 60, 43, 3)
fill(31, 31, 56, 39)
# 本堂の中の小部屋（北の戸から入る）
carve(38, 33, 49, 37)
carve(43, 31, 44, 32)
# 墓所（東の大きな丸い広場）
carve_ellipse(62, 24, 72, 42)
# 奥の広間（南。最後の大きな戦い。柱が並ぶ）
carve_oct(30, 45, 58, 50, 2)
# 奥の院（ボスの部屋。大きな丸い広場）
carve_ellipse(4, 38, 24, 50)

# ---- 通路 ----
carve(15, 6, 23, 7)        # 参道：開始の広場 → 山門
carve(58, 8, 62, 9)        # 境内 → 鐘楼
carve(43, 21, 44, 26)      # 境内 → 回廊（北）
carve(66, 14, 67, 23)      # 鐘楼 → 墓所
carve(61, 33, 62, 34)      # 回廊（東）→ 墓所
carve(7, 13, 8, 23)        # 開始の広場 → 僧坊
carve(15, 31, 28, 32)      # 僧坊 → 回廊（西）
carve(43, 44, 44, 44)      # 回廊（南）→ 奥の広間
carve(66, 43, 67, 47)      # 墓所 → 奥の広間（東の道）
carve(59, 46, 67, 47)
carve(21, 47, 29, 48)      # 奥の広間 → 奥の院（ボスの部屋。この道だけ）

# ---- 柱 ----
for px, py in [(36, 6), (36, 16), (44, 5), (44, 17), (52, 6), (52, 16)]:  # 境内の石灯籠
    pillar(px, py)
for px, py in [(35, 47), (41, 47), (47, 49), (53, 47), (38, 49), (56, 49)]:  # 奥の広間
    pillar(px, py)
for px, py in [(12, 41), (20, 41), (12, 48), (20, 48)]:  # 奥の院
    pillar(px, py)
for px, py in [(66, 28), (69, 36), (65, 38)]:  # 墓所の墓石
    pillar(px, py)

# ---- 印 ----
mark(7, 8, 'P')
mark(5, 4, 'D')
mark(11, 4, 'D')
mark(12, 10, 'C')            # 開始の広場の宝箱
# 山門
mark(27, 6, 'f')
mark(28, 8, 'L')
# 境内
mark(40, 10, 's')
mark(52, 13, 's')
mark(38, 14, 'r')
mark(54, 9, 'r')
mark(47, 9, 'f')
mark(54, 18, 'L')
# 鐘楼
mark(67, 7, 'f')
mark(69, 11, 'C')
# 僧坊
mark(6, 29, 'f')
mark(12, 33, 'C')
# 回廊
mark(28, 35, 's')
mark(58, 36, 's')
mark(42, 29, 's')
# 本堂の中
mark(43, 35, 'b')
mark(47, 36, 'C')
mark(40, 35, 'L')
# 墓所
mark(68, 32, 'b')
mark(67, 40, 'r')
mark(64, 28, 'r')
mark(69, 39, 'L')
# 奥の広間
mark(37, 48, 's')
mark(50, 47, 's')
mark(45, 47, 'b')
mark(55, 46, 'r')
mark(32, 47, 'C')
# 奥の院：ボス（X）は奥の中央。宝箱は置かない
mark(13, 45, 'X')

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, '..', '..', 'data', 'maps', 'field_01.txt')
with open(out, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(''.join(r) for r in g) + '\n')
counts = {}
for r in g:
    for c in r:
        if c not in '#.':
            counts[c] = counts.get(c, 0) + 1
print(out, W, H, counts)
