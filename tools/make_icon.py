from PIL import Image, ImageDraw, ImageFilter
import os

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "LocalPass", "Assets.xcassets", "AppIcon.appiconset", "AppIcon-1024.png",
)

img = Image.new("RGB", (SIZE, SIZE), "#3A46B8")
d = ImageDraw.Draw(img)

# 对角渐变背景
top = (56, 60, 186)
bottom = (104, 78, 232)
for y in range(SIZE):
    t = y / (SIZE - 1)
    r = int(top[0] + (bottom[0] - top[0]) * t)
    g = int(top[1] + (bottom[1] - top[1]) * t)
    b = int(top[2] + (bottom[2] - top[2]) * t)
    d.line([(0, y), (SIZE, y)], fill=(r, g, b))

# 背景装饰圆环
for radius, alpha in ((470, 18), (400, 15), (330, 12)):
    ring = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring)
    rd.ellipse(
        [SIZE // 2 - radius, SIZE // 2 - radius, SIZE // 2 + radius, SIZE // 2 + radius],
        outline=(255, 255, 255, alpha), width=3,
    )
    img = Image.alpha_composite(img.convert("RGBA"), ring).convert("RGB")

d = ImageDraw.Draw(img)

# 盾牌几何：上沿 250，肩部 520，底部 830
cx = SIZE / 2
shield_w = 420
left = cx - shield_w / 2
right = cx + shield_w / 2
top_y = 250
shoulder_y = 560
bottom_y = 830
points = [
    (left, top_y + 70),
    (left, shoulder_y),
    (cx, bottom_y),
    (right, shoulder_y),
    (right, top_y + 70),
    (cx, top_y - 20),
]

# 投影
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.polygon([(x + 8, y + 26) for x, y in points], fill=(18, 18, 60, 100))
shadow = shadow.filter(ImageFilter.GaussianBlur(30))
img = Image.alpha_composite(img.convert("RGBA"), shadow).convert("RGB")

# 盾牌本体（竖向浅色渐变）
shield = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(shield)
for y in range(int(top_y - 30), int(bottom_y) + 1):
    t = max(0.0, min(1.0, (y - top_y) / (bottom_y - top_y)))
    r = 255
    g = int(255 - 22 * t)
    b = int(255 - 46 * t)
    sd.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))
mask = Image.new("L", (SIZE, SIZE), 0)
md = ImageDraw.Draw(mask)
md.polygon(points, fill=255)
shield.putalpha(mask)
img = Image.alpha_composite(img.convert("RGBA"), shield).convert("RGB")
d = ImageDraw.Draw(img)

INK = (58, 62, 190)

# 锁：锁体中心约 y=560
body_w, body_h = 118, 104
body_left = cx - body_w / 2
body_top = 512
shackle_r = 34
shackle_width = 17
# 锁梁（开口向下的半圆）
d.arc(
    [cx - shackle_r, body_top - shackle_r - 4, cx + shackle_r, body_top + shackle_r - 4],
    start=185, end=355, fill=INK, width=shackle_width,
)
d.rectangle(
    [cx - shackle_r, body_top - 22, cx - shackle_r + shackle_width, body_top + 4],
    fill=INK,
)
d.rectangle(
    [cx + shackle_r - shackle_width, body_top - 22, cx + shackle_r, body_top + 4],
    fill=INK,
)
# 锁体
d.rounded_rectangle(
    [body_left, body_top, body_left + body_w, body_top + body_h],
    radius=24, fill=INK,
)
# 钥匙孔
keyhole_r = 15
keyhole_cy = body_top + 40
d.ellipse(
    [cx - keyhole_r, keyhole_cy - keyhole_r, cx + keyhole_r, keyhole_cy + keyhole_r],
    fill=(255, 255, 255),
)
d.polygon(
    [(cx - 8, keyhole_cy + 4), (cx + 8, keyhole_cy + 4),
     (cx + 5, keyhole_cy + 52), (cx - 5, keyhole_cy + 52)],
    fill=(255, 255, 255),
)

img.convert("RGB").save(OUT, "PNG")
print("saved", OUT)
