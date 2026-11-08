# 広いマップ data/maps/field_01.txt を作る。  python tools/maps/make_field_01.py
# 部屋と通路を四角で彫り、印（敵・宝箱・開始位置）を置く。経験値の見積もりは docs/map_field_01.md。
#
# 印：  # 壁   . 床   P 開始位置   D 案山子   C 宝箱
#       L レジェンドの宝箱の候補（超低確率で、1か所に出る）
#       f 小さなスライムの群れ(5匹)   s スライムの群れ(8〜14匹)   b 岩殻(1体)   X ボス(岩殻の主)
import os

W, H = 74, 52
g = [['#'] * W for _ in range(H)]


def carve(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = '.'


def mark(x, y, c):
    assert g[y][x] == '.', (x, y, c)
    g[y][x] = c


# 開始の広場（安全。案山子と宝箱）
carve(2, 2, 15, 12)
# 通路1：開始の広場 → 部屋A
carve(16, 6, 25, 7)
# 部屋A：小さな群れが2つ（スライムに慣れる）
carve(26, 2, 40, 13)
# 通路2：A → B
carve(32, 14, 33, 21)
# 部屋B：群れが3つ。奥に宝箱
carve(24, 22, 42, 35)
# 通路3：B → C
carve(43, 28, 52, 29)
# 部屋C：岩殻と小さな群れ（岩殻の遅さと硬さを知る）
carve(53, 21, 68, 34)
# 通路4：C → 広場E
carve(59, 35, 60, 40)
# 広場E：最後の大きな戦い。群れ4つと岩殻2体、宝箱2つ
carve(38, 41, 70, 49)
# 通路5：広場E → ボスの部屋（広場Eを抜けた先）
carve(27, 44, 37, 45)
# ボスの部屋：大きな丸い広場。ボスと、倒したあとの宝箱
carve(6, 38, 26, 50)
# 横道：通路1の途中から宝箱の小部屋（寄り道のごほうび）
carve(20, 8, 21, 11)
carve(17, 12, 24, 16)

mark(7, 8, 'P')
mark(5, 4, 'D')
mark(11, 4, 'D')
mark(13, 10, 'C')
# 部屋A
mark(31, 5, 'f')
mark(36, 10, 'f')
# 部屋B
mark(30, 29, 'r')
mark(35, 29, 'r')
mark(28, 26, 's')
mark(37, 26, 's')
mark(32, 32, 's')
mark(41, 34, 'C')
# 部屋C
mark(60, 26, 'b')
mark(57, 24, 'f')
mark(65, 31, 'f')
mark(63, 28, 'r')
# 広場E
mark(44, 45, 's')
mark(52, 44, 's')
mark(62, 45, 's')
mark(68, 43, 's')
mark(56, 46, 'r')
mark(65, 47, 'r')
mark(50, 47, 'b')
mark(60, 43, 'b')
mark(40, 43, 'C')
mark(69, 48, 'C')
# ボスの部屋：ボス（X）は奥の中央。宝箱は置かない
mark(13, 45, 'X')
# 超低確率で現れる、レジェンドの宝箱の候補（L）。毎回、このうちの1か所に、ごくまれに置く
mark(38, 4, 'L')
mark(66, 23, 'L')
mark(68, 47, 'L')
mark(26, 33, 'L')
# 寄り道の小部屋
mark(20, 14, 'C')

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
