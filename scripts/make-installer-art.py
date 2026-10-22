"""Creates the black and white Avysu artwork used by the NSIS installer."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "src-tauri", "installer")
FONT = os.path.join(ROOT, "assets", "Manrope.ttf")
os.makedirs(OUT, exist_ok=True)

def font(size, weight=600):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f

def panel(w, h, title):
    image = Image.new("RGB", (w, h), (16, 16, 16))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, w-1, h-1), outline=(80, 80, 80), width=1)
    draw.rectangle((0, 0, 6, h), fill=(245, 245, 245))
    f = font(21 if h > 100 else 15, 700)
    draw.text((18 if h > 100 else 46, h * .72 if h > 100 else 17), title, font=f, fill=(248, 248, 248))
    return image

side = panel(164, 314, "Avysu")
side.save(os.path.join(OUT, "sidebar.bmp"))
head = panel(150, 57, "Avysu")
head.save(os.path.join(OUT, "header.bmp"))
# превью для проверки
prev = Image.new("RGB", (164 + 20 + 150, 314), (240, 240, 240))
prev.paste(side, (0, 0)); prev.paste(head, (184, 0))
prev.save(os.path.join(OUT, "_preview.png"))
print("ok")
