"""Generate Avysu's black and white A mark and monochrome tray icons."""
from PIL import Image, ImageDraw
import os
ROOT=os.path.join(os.path.dirname(__file__),"..")

def mark(size, dark=False, state=None):
    bg=(12,12,12,255) if dark else (248,248,246,255)
    fg=(248,248,246,255) if dark else (12,12,12,255)
    img=Image.new("RGBA",(size,size),bg); d=ImageDraw.Draw(img); k=size/256
    d.line([(50*k,198*k),(128*k,48*k),(206*k,198*k)],fill=fg,width=max(2,int(22*k)),joint="curve")
    d.line([(82*k,148*k),(176*k,148*k)],fill=fg,width=max(2,int(18*k)))
    d.line([(128*k,148*k),(128*k,198*k)],fill=bg,width=max(2,int(20*k)))
    if state:
        d.ellipse((177*k,177*k,229*k,229*k),fill=state)
    return img

os.makedirs(os.path.join(ROOT,"assets"),exist_ok=True)
mark(1024).save(os.path.join(ROOT,"assets","logo.png"))
mark(256).save(os.path.join(ROOT,"ui","logo.png"))
icons=os.path.join(ROOT,"src-tauri","icons")
os.makedirs(icons,exist_ok=True)
mark(64,True,(255,255,255,255)).save(os.path.join(icons,"tray-on.png"))
mark(64).save(os.path.join(icons,"tray-off.png"))
mark(64,False,(140,140,140,255)).save(os.path.join(icons,"tray-busy.png"))
