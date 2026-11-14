"""按新的深色玻璃设计系统渲染 4 个界面预览（用于检查视觉效果）。"""
import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "preview")
os.makedirs(OUT, exist_ok=True)

S = 2
W, H = 390 * S, 844 * S

VIOLET = (124, 108, 255)
VIOLET2 = (155, 140, 255)
CYAN = (63, 217, 245)
MINT = (62, 230, 168)
PINK = (255, 122, 182)
AMBER = (255, 192, 97)
TEXT = (243, 245, 255)
TEXT2 = (186, 192, 224)
TEXT3 = (150, 157, 190)
STROKE = (255, 255, 255, 24)
CARD_TOP = (255, 255, 255, 22)
CARD_BOT = (255, 255, 255, 8)
INK = (11, 14, 26)

FONT_DIR = r"C:\Windows\Fonts"
REG = os.path.join(FONT_DIR, "msyh.ttc")
BOLD = os.path.join(FONT_DIR, "msyhbd.ttc")


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else REG, max(1, int(size * S)))


def txt(d, x, y, s, size=14, bold=False, fill=TEXT, anchor="la", alpha=255):
    f = font(size, bold)
    d.text((x * S, y * S), s, font=f, fill=fill + (alpha,) if len(fill) == 3 else fill, anchor=anchor)


def measure(d, s, size=14, bold=False):
    return d.textlength(s, font=font(size, bold)) / S


def rr(d, box, r, fill=None, outline=None, width=1):
    d.rounded_rectangle([v * S for v in box], radius=r * S, fill=fill,
                        outline=outline, width=max(1, int(width * S)) if outline else 0)


def lin(box, top, bottom, r):
    """带透视感的竖向渐变圆角矩形，贴到画布上。"""
    x0, y0, x1, y1 = [int(v * S) for v in box]
    w, h = x1 - x0, y1 - y0
    if w <= 0 or h <= 0:
        return None
    grad = Image.new("RGBA", (w, h))
    gd = ImageDraw.Draw(grad)
    for i in range(h):
        t = i / max(1, h - 1)
        c = tuple(int(top[j] + (bottom[j] - top[j]) * t) for j in range(len(top)))
        gd.line([(0, i), (w, i)], fill=c)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=r * S, fill=255)
    return grad, mask, (x0, y0)


def bg_card(canvas, box, r=18, top=CARD_TOP, bot=CARD_BOT, stroke=STROKE):
    """把半透明玻璃卡片真正叠加到画布上（保留背景透出来）。"""
    g = lin(box, top, bot, r)
    if not g:
        return
    grad, mask, (x0, y0) = g
    w, h = grad.size
    region = canvas.crop((x0, y0, x0 + w, y0 + h)).convert("RGBA")
    region = Image.alpha_composite(region, grad)
    canvas.paste(region.convert("RGB"), (x0, y0))
    ImageDraw.Draw(canvas).rounded_rectangle(
        [v * S for v in box], radius=r * S, outline=stroke, width=max(1, int(1.2 * S)))


def base_canvas():
    img = Image.new("RGB", (W, H), (8, 10, 19))
    d = ImageDraw.Draw(img)
    # 极光光晕
    for (cx, cy, rad, color, alpha) in [
        (60, 40, 240, VIOLET, 120), (350, 180, 210, CYAN, 60),
        (160, 820, 300, PINK, 55), (330, 760, 220, VIOLET, 50),
    ]:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.ellipse([(cx - rad) * S, (cy - rad) * S, (cx + rad) * S, (cy + rad) * S],
                   fill=color + (alpha,))
        layer = layer.filter(ImageFilter.GaussianBlur(70 * S / 2))
        img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    # 顶部提亮
    d = ImageDraw.Draw(img)
    for y in range(0, 200 * S):
        a = int(28 * (1 - y / (200 * S)))
        d.line([(0, y), (W, y)], fill=(18, 22, 44), width=1)
    return img


def status(d):
    txt(d, 24, 16, "9:41", 12, bold=True)
    txt(d, 340, 16, "5G", 10, bold=True, anchor="ra")
    for i in range(3):
        d.rounded_rectangle([(312 + i * 7) * S, (17 - i * 2) * S, (316 + i * 7) * S, 23 * S],
                            radius=1.5 * S, fill=TEXT)
    d.rounded_rectangle([322 * S, 16 * S, 340 * S, 23 * S], radius=2 * S, outline=TEXT + (150,), width=S)
    d.rounded_rectangle([324 * S, 18 * S, 333 * S, 21 * S], radius=1 * S, fill=TEXT)


def glyph_icon(d, kind, cx, cy, size, color):
    """极简几何图标：bot / shield / key / search / copy / plus / gear / face / hand / chevron。"""
    k = size / 24.0
    lw = max(1, int(1.9 * k * S))
    c = color if len(color) == 4 else color + (255,)
    if kind == "bot":
        d.rounded_rectangle([(cx - 8 * k) * S, (cy - 6 * k) * S, (cx + 8 * k) * S, (cy + 8 * k) * S],
                            radius=4 * k * S, outline=c, width=lw)
        for dx in (-3.4, 3.4):
            d.ellipse([(cx + dx * k - 1.2 * k) * S, (cy - 1.2 * k) * S,
                       (cx + dx * k + 1.2 * k) * S, (cy + 1.2 * k) * S], fill=c)
        d.line([(cx - 3 * k) * S, (cy + 4 * k) * S, (cx + 3 * k) * S, (cy + 4 * k) * S], fill=c, width=lw)
    elif kind == "shield":
        pts = [(cx, cy - 9 * k), (cx + 7.5 * k, cy - 5 * k), (cx + 7.5 * k, cy + 1 * k),
               (cx, cy + 9 * k), (cx - 7.5 * k, cy + 1 * k), (cx - 7.5 * k, cy - 5 * k)]
        d.polygon([(x * S, y * S) for x, y in pts], fill=c)
        d.rounded_rectangle([(cx - 2.6 * k) * S, (cy - 1 * k) * S, (cx + 2.6 * k) * S, (cy + 4 * k) * S],
                            radius=1 * k * S, fill=INK)
    elif kind == "key":
        d.ellipse([(cx - 8 * k) * S, (cy - 8 * k) * S, (cx - 1 * k) * S, (cy - 1 * k) * S], outline=c, width=lw)
        d.line([(cx - 3 * k) * S, (cy - 3 * k) * S, (cx + 8 * k) * S, (cy + 8 * k) * S], fill=c, width=lw)
        d.line([(cx + 4 * k) * S, (cy + 4 * k) * S, (cx + 7 * k) * S, (cy + 1 * k) * S], fill=c, width=lw)
    elif kind == "search":
        d.ellipse([(cx - 7 * k) * S, (cy - 7 * k) * S, (cx + 3 * k) * S, (cy + 3 * k) * S], outline=c, width=lw)
        d.line([(cx + 2.5 * k) * S, (cy + 2.5 * k) * S, (cx + 8 * k) * S, (cy + 8 * k) * S], fill=c, width=lw)
    elif kind == "copy":
        d.rounded_rectangle([(cx - 6 * k) * S, (cy - 3 * k) * S, (cx + 3 * k) * S, (cy + 6 * k) * S],
                            radius=2 * k * S, outline=c, width=max(1, int(1.7 * k * S)))
        d.rounded_rectangle([(cx - 1 * k) * S, (cy - 7 * k) * S, (cx + 6 * k) * S, (cy + 2 * k) * S],
                            radius=2 * k * S, outline=c, width=max(1, int(1.7 * k * S)))
    elif kind == "plus":
        d.line([(cx - 5 * k) * S, cy * S, (cx + 5 * k) * S, cy * S], fill=c, width=max(1, int(2.2 * k * S)))
        d.line([cx * S, (cy - 5 * k) * S, cx * S, (cy + 5 * k) * S], fill=c, width=max(1, int(2.2 * k * S)))
    elif kind == "gear":
        d.ellipse([(cx - 4 * k) * S, (cy - 4 * k) * S, (cx + 4 * k) * S, (cy + 4 * k) * S], outline=c, width=lw)
        d.ellipse([(cx - 1.6 * k) * S, (cy - 1.6 * k) * S, (cx + 1.6 * k) * S, (cy + 1.6 * k) * S], outline=c, width=lw)
        for i in range(8):
            a = math.radians(i * 45)
            d.line([(cx + 4 * k * math.cos(a)) * S, (cy + 4 * k * math.sin(a)) * S,
                    (cx + 6.5 * k * math.cos(a)) * S, (cy + 6.5 * k * math.sin(a)) * S], fill=c, width=lw)
    elif kind == "face":
        d.rounded_rectangle([(cx - 8 * k) * S, (cy - 8 * k) * S, (cx + 8 * k) * S, (cy + 8 * k) * S],
                            radius=5 * k * S, outline=c, width=lw)
        for dx in (-3, 3):
            d.ellipse([(cx + dx * k - 1 * k) * S, (cy - 2.5 * k) * S,
                       (cx + dx * k + 1 * k) * S, (cy - 0.5 * k) * S], fill=c)
        d.arc([(cx - 4 * k) * S, (cy - 1 * k) * S, (cx + 4 * k) * S, (cy + 6 * k) * S], 20, 160, fill=c, width=lw)
    elif kind == "hand":
        d.rounded_rectangle([(cx - 8 * k) * S, (cy - 8 * k) * S, (cx + 8 * k) * S, (cy + 8 * k) * S],
                            radius=5 * k * S, outline=c, width=lw)
        d.line([(cx - 4 * k) * S, (cy + 4 * k) * S, (cx - 1 * k) * S, (cy - 3 * k) * S,
                (cx + 3 * k) * S, (cy + 1 * k) * S], fill=c, width=lw)
    elif kind == "chevron":
        d.line([(cx - 2 * k) * S, (cy - 4 * k) * S, (cx + 2.5 * k) * S, cy * S,
                (cx - 2 * k) * S, (cy + 4 * k) * S], fill=c, width=lw)
    elif kind == "clock":
        d.ellipse([(cx - 8 * k) * S, (cy - 8 * k) * S, (cx + 8 * k) * S, (cy + 8 * k) * S], outline=c, width=lw)
        d.line([cx * S, (cy - 5 * k) * S, cx * S, cy * S, (cx + 4 * k) * S, (cy + 2 * k) * S], fill=c, width=lw)
    elif kind == "eye":
        d.arc([(cx - 8 * k) * S, (cy - 7 * k) * S, (cx + 8 * k) * S, (cy + 7 * k) * S], 200, 340, fill=c, width=lw)
        d.arc([(cx - 8 * k) * S, (cy - 7 * k) * S, (cx + 8 * k) * S, (cy + 7 * k) * S], 20, 160, fill=c, width=lw)
        d.ellipse([(cx - 2.2 * k) * S, (cy - 2.2 * k) * S, (cx + 2.2 * k) * S, (cy + 2.2 * k) * S], fill=c)
    elif kind == "archive":
        d.rounded_rectangle([(cx - 8 * k) * S, (cy - 6 * k) * S, (cx + 8 * k) * S, (cy + 7 * k) * S],
                            radius=3 * k * S, outline=c, width=lw)
        d.line([(cx - 8 * k) * S, (cy - 1 * k) * S, (cx + 8 * k) * S, (cy - 1 * k) * S], fill=c, width=lw)
    elif kind == "trash":
        d.line([(cx - 7 * k) * S, (cy - 6 * k) * S, (cx + 7 * k) * S, (cy - 6 * k) * S], fill=c, width=lw)
        d.rounded_rectangle([(cx - 5 * k) * S, (cy - 6 * k) * S, (cx + 5 * k) * S, (cy + 7 * k) * S],
                            radius=2 * k * S, outline=c, width=lw)


def brand_avatar(canvas, cx, cy, size, color, glyph="bag", letter=None):
    box = (cx - size / 2, cy - size / 2, cx + size / 2, cy + size / 2)
    r = size * 0.3
    g = lin(box, color + (66,), color + (16,), r)
    if g:
        grad, mask, pos = g
        canvas.paste(grad, pos, mask)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle([v * S for v in box], radius=r * S, outline=color + (40,), width=max(1, int(1.2 * S)))
    if letter:
        txt(d, cx, cy + 1, letter, int(size * 0.40), bold=True, fill=color, anchor="mm")
        return
    inset = size * 0.26
    glyph_icon(d, glyph, cx, cy, size * 0.52, color)


# ============================================================ 1 锁屏
def screen_lock():
    img = base_canvas()
    d = ImageDraw.Draw(img)
    status(d)

    # logo
    cx, cy = 195, 150
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([(cx - 76) * S, (cy - 76) * S, (cx + 76) * S, (cy + 76) * S], fill=VIOLET + (150,))
    img = Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(40 * S / 2))).convert("RGB")
    d = ImageDraw.Draw(img)

    g = lin((cx - 55, cy - 55, cx + 55, cy + 55), (62, 56, 170, 255), (150, 110, 255, 255), 30)
    if g:
        grad, mask, pos = g
        img.paste(grad, pos, mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([(cx - 55) * S, (cy - 55) * S, (cx + 55) * S, (cy + 55) * S],
                        radius=30 * S, outline=(255, 255, 255, 40), width=S)
    glyph_icon(d, "shield", cx, cy, 56, (255, 255, 255))

    txt(d, 195, 232, "私钥库", 30, bold=True, anchor="ma")
    txt(d, 195, 270, "输入主密码解锁", 14, fill=TEXT2, anchor="ma")

    # 输入框
    bg_card(img, (24, 316, 366, 372), 18, (255, 255, 255, 20), (255, 255, 255, 10), (255, 255, 255, 34))
    d = ImageDraw.Draw(img)
    glyph_icon(d, "key", 44, 344, 18, TEXT3)
    txt(d, 62, 344, "主密码", 16, fill=(255, 255, 255, 105), anchor="lm")

    # 主按钮
    g = lin((24, 384, 366, 438), (108, 91, 255, 255), (162, 107, 255, 255), 16)
    if g:
        grad, mask, pos = g
        img.paste(grad, pos, mask)
    d = ImageDraw.Draw(img)
    txt(d, 195, 411, "解锁", 17, bold=True, fill=(255, 255, 255), anchor="mm")

    # Face ID
    bg_card(img, (24, 452, 366, 504), 16, (255, 255, 255, 22), (255, 255, 255, 10), (255, 255, 255, 28))
    d = ImageDraw.Draw(img)
    glyph_icon(d, "face", 128, 478, 19, (255, 255, 255))
    txt(d, 146, 478, "使用 Face ID 解锁", 15, bold=True, fill=(255, 255, 255), anchor="lm")
    txt(d, 195, 536, "使用手势解锁", 13.5, fill=TEXT2, anchor="mm")

    txt(d, 195, 742, "数据只保存在此浏览器本地", 12, fill=TEXT3, anchor="ma")
    txt(d, 195, 762, "忘记主密码将无法找回", 11, fill=(110, 117, 150), anchor="ma")
    d.rounded_rectangle([145 * S, 806 * S, 245 * S, 810 * S], radius=2 * S, fill=(255, 255, 255, 90))
    return img


# ============================================================ 2 主页
def hero_bar(img, title, subtitle, media=False):
    """顶部玻璃主卡：图标 + 标题 + 统计 + 两个胶囊统计。"""
    box = (16, 42, 374, 178)
    g = lin(box, (86, 76, 170, 255), (42, 48, 96, 255), 24)
    if g:
        grad, mask, pos = g
        img.paste(grad, pos, mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([v * S for v in box], radius=24 * S, outline=(255, 255, 255, 34), width=S)
    # 右上角光斑
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([(300 - 90) * S, (42 - 40) * S, (300 + 90) * S, (42 + 100) * S], fill=(255, 255, 255, 46))
    img.paste(Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(30 * S / 2))).convert("RGB"), (0, 0))

    d = ImageDraw.Draw(img)
    # 左侧图标
    gg = lin((30, 58, 82, 110), (108, 91, 255, 255), (170, 110, 255, 255), 17)
    if gg:
        grad, mask, pos = gg
        img.paste(grad, pos, mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([30 * S, 58 * S, 82 * S, 110 * S], radius=17 * S, outline=(255, 255, 255, 46), width=S)
    glyph_icon(d, "archive" if media else "shield", 56, 84, 27, (255, 255, 255))

    txt(d, 94, 62, "本地保险箱", 10, bold=True, fill=(235, 239, 255, 130))
    txt(d, 94, 76, title, 25, bold=True, fill=(255, 255, 255))
    txt(d, 94, 108, subtitle, 11.5, fill=(235, 239, 255, 140))

    # 右上两个按钮
    bg_card(img, (286, 58, 324, 96), 13, (255, 255, 255, 24), (255, 255, 255, 8), (255, 255, 255, 34))
    bg_card(img, (330, 58, 368, 96), 13, (108, 91, 255, 255), (150, 110, 255, 255), (255, 255, 255, 40))
    d = ImageDraw.Draw(img)
    glyph_icon(d, "gear", 305, 77, 17, (255, 255, 255))
    if not media:
        glyph_icon(d, "plus", 349, 77, 18, (255, 255, 255))

    # 底部两个统计胶囊
    for i, (sym, n, label) in enumerate([("key", "6", "条账号记录"), ("media", "12", "个媒体文件")]):
        bx = 30 + i * 170
        bg_card(img, (bx, 128, bx + 158, 164), 14, (255, 255, 255, 22), (255, 255, 255, 6), (255, 255, 255, 26))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([(bx + 10) * S, 138 * S, (bx + 36) * S, 164 * S - 10 * S], radius=9 * S, fill=(255, 255, 255, 26))
        glyph_icon(d, sym if sym in ("key", "gear") else "archive", bx + 23, 146, 14, (255, 255, 255))
        txt(d, bx + 46, 137, n, 14, bold=True, fill=(255, 255, 255))
        txt(d, bx + 46, 154, label, 10, fill=(235, 239, 255, 130))
    return img


def screen_home(with_tabs=True, active="passwords"):
    img = base_canvas()
    d = ImageDraw.Draw(img)
    status(d)
    hero_bar(img, "密码库", "共 6 条记录 · 只存本浏览器", False)
    d = ImageDraw.Draw(img)

    y0 = 190
    if with_tabs:
        draw_vault_tabs(img, active, 190)
        y0 = 252

    # 分类胶囊
    cats = [("全部", True), ("网站", False), ("软件", False), ("邮箱", False), ("金融", False)]
    x = 22
    for name, on in cats:
        w = measure(d, name, 13) + 28
        if on:
            g = lin((x, y0, x + w, y0 + 34), (108, 91, 255, 255), (162, 107, 255, 255), 17)
            if g:
                grad, mask, pos = g
                img.paste(grad, pos, mask)
            d = ImageDraw.Draw(img)
            txt(d, x + w / 2, y0 + 17, name, 13, bold=True, fill=(255, 255, 255), anchor="mm")
        else:
            bg_card(img, (x, y0, x + w, y0 + 34), 17, (255, 255, 255, 18), (255, 255, 255, 8), (255, 255, 255, 24))
            d = ImageDraw.Draw(img)
            txt(d, x + w / 2, y0 + 17, name, 13, fill=TEXT2, anchor="mm")
        x += w + 8

    # 搜索
    bg_card(img, (22, y0 + 48, 368, y0 + 92), 15, (255, 255, 255, 18), (255, 255, 255, 8), (255, 255, 255, 22))
    d = ImageDraw.Draw(img)
    glyph_icon(d, "search", 40, y0 + 70, 16, TEXT3)
    txt(d, 56, y0 + 70, "搜索名称、账号、标签", 13.5, fill=TEXT3, anchor="lm")

    rows = [
        ("淘宝", "me@example.com", (255, 80, 0), "bag", False),
        ("招商银行", "6225 ···· 8899", (53, 194, 122), "wallet", True),
        ("iCloud 邮箱", "someone@icloud.com", (54, 147, 243), "cloud", False),
        ("阿里云服务器", "root@47.100.··.··", (255, 106, 0), "cloud", False),
        ("微信", "+86 138 ···· 0000", (7, 193, 96), "chat", False),
        ("路由器后台", "admin", (140, 147, 166), "globe", False),
    ]
    y = y0 + 58
    for name, user, color, glyph, pinned in rows:
        bg_card(img, (18, y, 372, y + 66), 18)
        brand_avatar(img, 48, y + 33, 42, color, glyph)
        d = ImageDraw.Draw(img)
        tx = 80
        if pinned:
            d.ellipse([(tx - 1) * S, (y + 22) * S, (tx + 4) * S, (y + 27) * S], fill=AMBER)
            tx += 12
        txt(d, tx, y + 24, name, 15, bold=True, anchor="lm")
        txt(d, 80, y + 45, user, 12, fill=TEXT2, anchor="lm")
        bg_card(img, (322, y + 14, 360, y + 52), 13, (124, 108, 255, 34), (124, 108, 255, 60), (124, 108, 255, 56))
        d = ImageDraw.Draw(img)
        glyph_icon(d, "copy", 341, y + 33, 17, VIOLET2)
        y += 75

    # fab
    g = lin((300, 762, 362, 824), (108, 91, 255, 255), (170, 110, 255, 255), 20)
    if g:
        grad, mask, pos = g
        img.paste(grad, pos, mask)
    d = ImageDraw.Draw(img)
    glyph_icon(d, "plus", 331, 793, 24, (255, 255, 255))
    return img


# ============================================================ 2.5 保险箱切换
def draw_vault_tabs(img, active, y=190):
    d = ImageDraw.Draw(img)
    box = (22, y, 368, y + 44)
    bg_card(img, box, 16, (255, 255, 255, 18), (255, 255, 255, 6), (255, 255, 255, 22))
    d = ImageDraw.Draw(img)
    half = (box[2] - box[0] - 10) / 2
    x0 = box[0] + 5 + (half + 4 if active == "media" else 0)
    g = lin((x0, box[1] + 5, x0 + half, box[3] - 5), (108, 91, 255, 255), (162, 107, 255, 255), 13)
    if g:
        grad, mask, pos = g
        img.paste(grad, pos, mask)
    d = ImageDraw.Draw(img)
    cx1 = box[0] + 5 + half / 2
    cx2 = box[2] - 5 - half / 2
    txt(d, cx1, y + 22, "密码库", 13, bold=True, fill=(255, 255, 255) if active == "passwords" else TEXT2, anchor="mm")
    txt(d, cx2, y + 22, "图片视频库", 13, bold=True, fill=(255, 255, 255) if active == "media" else TEXT2, anchor="mm")


# ============================================================ 2.8 媒体库
def screen_media():
    img = base_canvas()
    d = ImageDraw.Draw(img)
    status(d)

    hero_bar(img, "图片视频库", "共 12 个文件 · 9 张照片 · 3 个视频", True)
    d = ImageDraw.Draw(img)
    draw_vault_tabs(img, "media", 190)
    d = ImageDraw.Draw(img)

    # 分段筛选 + 导入
    bg_card(img, (22, 252, 262, 290), 13, (255, 255, 255, 16), (255, 255, 255, 6), (255, 255, 255, 20))
    g = lin((25, 255, 104, 287), (255, 255, 255, 30), (255, 255, 255, 18), 10)
    d = ImageDraw.Draw(img)
    txt(d, 64, 271, "全部", 13, bold=True, fill=TEXT, anchor="mm")
    txt(d, 146, 271, "照片", 13, fill=TEXT3, anchor="mm")
    txt(d, 216, 271, "视频", 13, fill=TEXT3, anchor="mm")
    bg_card(img, (272, 252, 368, 290), 13, (124, 108, 255, 40), (124, 108, 255, 30), (124, 108, 255, 60))
    txt(d, 320, 271, "导入", 13, bold=True, fill=VIOLET2, anchor="mm")

    # 缩略图网格 3x4
    colors = [(255, 120, 90), (90, 160, 255), (90, 220, 190), (200, 140, 255), (255, 190, 90), (120, 220, 120),
              (255, 130, 180), (140, 160, 255), (255, 170, 120), (110, 200, 230), (190, 150, 255), (150, 210, 170)]
    vids = {1, 5, 8}
    x0, y0, gap = 18, 302, 7
    cell = (368 - x0 * 2 - gap * 2) / 3
    for i in range(12):
        r, c = divmod(i, 3)
        x = x0 + c * (cell + gap)
        y = y0 + r * (cell + gap)
        c1 = colors[i]
        c2 = tuple(max(0, v - 55) for v in c1)
        g = lin((x, y, x + cell, y + cell), c1 + (255,), c2 + (255,), 14)
        if g:
            grad, mask, pos = g
            img.paste(grad, pos, mask)
            # 内容装饰：几条斜线，模拟照片
            dd = ImageDraw.Draw(img)
            for k in range(3):
                dd.line([(x + 10 + k * 18) * S, (y + cell - 12) * S, (x + 30 + k * 18) * S, (y + cell - 34) * S],
                        fill=(255, 255, 255, 40), width=2 * S)
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([x * S, y * S, (x + cell) * S, (y + cell) * S], radius=14 * S,
                            outline=(255, 255, 255, 34), width=S)
        if i in vids:
            d.ellipse([(x + cell / 2 - 13) * S, (y + cell / 2 - 13) * S,
                       (x + cell / 2 + 13) * S, (y + cell / 2 + 13) * S], fill=(6, 8, 16, 120))
            d.polygon([((x + cell / 2 - 4) * S, (y + cell / 2 - 7) * S),
                       ((x + cell / 2 + 7) * S, (y + cell / 2) * S),
                       ((x + cell / 2 - 4) * S, (y + cell / 2 + 7) * S)], fill=(255, 255, 255))
            label = "0:4" + str(i % 9)
        else:
            label = str(800 + i * 37) + "KB"
        bw = measure(d, label, 10) + 16
        d.rounded_rectangle([(x + cell - bw - 6) * S, (y + cell - 24) * S, (x + cell - 6) * S, (y + cell - 6) * S],
                            radius=7 * S, fill=(6, 8, 16, 170))
        txt(d, x + cell - bw / 2 - 6, y + cell - 15, label, 9.5, bold=True, fill=(255, 255, 255), anchor="mm")
    return img


# ============================================================ 3 详情
def screen_detail():
    img = base_canvas()
    d = ImageDraw.Draw(img)
    status(d)
    bg_card(img, (22, 46, 62, 86), 14, (255, 255, 255, 18), (255, 255, 255, 8), (255, 255, 255, 24))
    bg_card(img, (330, 46, 370, 86), 14, (255, 255, 255, 18), (255, 255, 255, 8), (255, 255, 255, 24))
    glyph_icon(d, "chevron", 42, 66, 18, TEXT)
    glyph_icon(d, "gear", 350, 66, 17, TEXT)

    # glow + avatar
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([(195 - 80) * S, (150 - 80) * S, (195 + 80) * S, (150 + 80) * S], fill=(255, 80, 0, 110))
    img = Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(46 * S / 2))).convert("RGB")
    brand_avatar(img, 195, 150, 76, (255, 80, 0), "bag")
    d = ImageDraw.Draw(img)

    txt(d, 195, 208, "淘宝", 23, bold=True, anchor="mm")
    for i, (label, w) in enumerate([("网站", 52), ("#购物", 62), ("#常用", 62)]):
        x = 195 - 90 + i * 64
        bg_card(img, (x, 228, x + w, 254), 13, (124, 108, 255, 40), (124, 108, 255, 30), (124, 108, 255, 62))
        txt(ImageDraw.Draw(img), x + w / 2, 241, label, 11.5, fill=VIOLET2, anchor="mm")

    # 凭证卡
    bg_card(img, (18, 274, 372, 396), 18)
    d = ImageDraw.Draw(img)
    txt(d, 34, 294, "账号", 10.5, bold=True, fill=TEXT3)
    txt(d, 34, 312, "me@example.com", 15)
    bg_card(img, (318, 296, 356, 334), 13, (124, 108, 255, 34), (124, 108, 255, 50), (124, 108, 255, 56))
    d = ImageDraw.Draw(img)
    glyph_icon(d, "copy", 337, 315, 16, VIOLET2)
    d.line([34 * S, 342 * S, 356 * S, 342 * S], fill=(255, 255, 255, 20), width=S)
    txt(d, 34, 360, "密码", 10.5, bold=True, fill=TEXT3)
    txt(d, 34, 380, "••••••••••", 15)
    bg_card(img, (272, 356, 308, 392), 12, (124, 108, 255, 34), (124, 108, 255, 50), (124, 108, 255, 56))
    bg_card(img, (314, 356, 350, 392), 12, (124, 108, 255, 34), (124, 108, 255, 50), (124, 108, 255, 56))
    d = ImageDraw.Draw(img)
    glyph_icon(d, "eye", 290, 374, 16, VIOLET2)
    glyph_icon(d, "copy", 332, 374, 16, VIOLET2)

    # 信息卡
    bg_card(img, (18, 410, 372, 540), 18)
    d = ImageDraw.Draw(img)
    txt(d, 34, 430, "网址", 10.5, bold=True, fill=TEXT3)
    txt(d, 34, 448, "https://www.taobao.com", 12.5, fill=VIOLET2)
    txt(d, 34, 476, "标签", 10.5, bold=True, fill=TEXT3)
    bg_card(img, (34, 494, 96, 520), 13, (124, 108, 255, 40), (124, 108, 255, 30), (124, 108, 255, 62))
    bg_card(img, (102, 494, 164, 520), 13, (124, 108, 255, 40), (124, 108, 255, 30), (124, 108, 255, 62))
    d = ImageDraw.Draw(img)
    txt(d, 65, 507, "#购物", 11.5, fill=VIOLET2, anchor="mm")
    txt(d, 133, 507, "#常用", 11.5, fill=VIOLET2, anchor="mm")
    txt(d, 34, 536, "备注：2024 年换过绑定手机号", 11, fill=TEXT2)

    bg_card(img, (18, 554, 372, 592), 16)
    txt(ImageDraw.Draw(img), 34, 573, "最近修改  2026年11月14日 09:00", 11, fill=TEXT3, anchor="lm")

    bg_card(img, (18, 604, 372, 650), 16, (255, 107, 122, 28), (255, 107, 122, 12), (255, 107, 122, 40))
    txt(ImageDraw.Draw(img), 195, 627, "删除这条记录", 13, bold=True, fill=(255, 154, 165), anchor="mm")
    return img


# ============================================================ 4 设置
def screen_settings():
    img = base_canvas()
    d = ImageDraw.Draw(img)
    status(d)
    bg_card(img, (22, 46, 62, 86), 14, (255, 255, 255, 18), (255, 255, 255, 8), (255, 255, 255, 24))
    glyph_icon(d, "chevron", 42, 66, 18, TEXT)
    txt(d, 22, 108, "设置", 26, bold=True)

    def section(y, label):
        txt(d, 24, y, label, 10.5, bold=True, fill=TEXT3, anchor="lm")
        return y + 14

    def row(y, glyph, label, sub, color=VIOLET, h=64):
        bg_card(img, (18, y, 372, y + h), 16)
        dd = ImageDraw.Draw(img)
        g = lin((32, y + 16, 66, y + 50), (color[0], color[1], color[2], 255), (max(0, color[0] - 40), max(0, color[1] - 40), min(255, color[2] + 30), 255), 12)
        if g:
            grad, mask, pos = g
            img.paste(grad, pos, mask)
        dd = ImageDraw.Draw(img)
        glyph_icon(dd, glyph, 49, y + 33, 17, (255, 255, 255))
        txt(dd, 80, y + 26, label, 14, bold=False, anchor="lm")
        if sub:
            txt(dd, 80, y + 44, sub, 11.5, fill=TEXT3, anchor="lm")
        glyph_icon(dd, "chevron", 354, y + 32, 14, TEXT3)

    y = section(148, "解锁方式")
    row(y, "face", "系统验证解锁", "已开启", CYAN); y += 70
    row(y, "hand", "手势解锁", "已设置", VIOLET); y += 70
    row(y, "key", "修改主密码", "主密码始终有效", (155, 140, 255)); y += 78

    y = section(y, "安全")
    row(y, "clock", "自动锁定", "无操作后重新上锁", AMBER); y += 70
    row(y, "archive", "复制后自动清空剪贴板", "30 秒后", CYAN); y += 78

    y = section(y, "数据")
    row(y, "archive", "导出加密备份", "独立密码加密的 .lpbk 文件", MINT); y += 70
    row(y, "archive", "从备份恢复", "覆盖当前库内容", (155, 140, 255)); y += 60

    # 清空
    bg_card(img, (18, y, 372, y + 54), 16, (255, 107, 122, 24), (255, 107, 122, 8), (255, 107, 122, 34))
    d = ImageDraw.Draw(img)
    glyph_icon(d, "trash", 40, y + 27, 17, (255, 154, 165))
    txt(d, 62, y + 27, "清空所有数据并重置", 13, fill=(255, 154, 165), anchor="lm")
    return img


def main():
    screens = [
        ("锁屏 · 玻璃质感 + 光晕", screen_lock()),
        ("密码库 · 顶部可切换", screen_home(True, "passwords")),
        ("图片视频库 · 缩略图网格", screen_media()),
        ("详情 · 品牌光晕", screen_detail()),
        ("设置 · 图标化分组", screen_settings()),
    ]
    cols, pad, gap, label_h = 5, 20, 16, 22
    inner_w, inner_h = W // S, H // S
    cw = pad * 2 + cols * inner_w + (cols - 1) * gap
    ch = pad * 2 + inner_h + label_h
    scale = min(1.0, 1500 / cw)
    canvas = Image.new("RGB", (int(cw * scale), int(ch * scale)), (5, 6, 12))
    d = ImageDraw.Draw(canvas)
    for i, (label, img) in enumerate(screens):
        x = pad + i * (inner_w + gap)
        thumb = img.resize((inner_w, inner_h), Image.LANCZOS)
        mask = Image.new("L", thumb.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, inner_w, inner_h], radius=20, fill=255)
        canvas.paste(thumb, (x, pad), mask)
        d.rounded_rectangle([x, pad, x + inner_w, pad + inner_h], radius=20, outline=(44, 48, 70), width=1)
        d.text((x + inner_w / 2, pad + inner_h + 5), label, font=ImageFont.truetype(REG, 12),
               fill=(150, 156, 190), anchor="ma")
    out = os.path.join(OUT, "ui-preview.png")
    canvas.save(out, "PNG")
    print("saved", out, canvas.size)
    for i, (_, img) in enumerate(screens):
        img.resize((inner_w, inner_h), Image.LANCZOS).save(os.path.join(OUT, f"screen-{i + 1}.png"), "PNG")


if __name__ == "__main__":
    main()
