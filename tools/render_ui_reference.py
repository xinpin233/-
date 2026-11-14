"""Render a standalone UI art direction, not a replacement for the live game."""
from pathlib import Path
import math
import random
import struct
import wave

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts" / "ui_reference"
OUT.mkdir(parents=True, exist_ok=True)
W, H, S = 1920, 1080, 2
CREAM = "#d0c8ae"
INK = "#181d19"
GREEN = "#8adba4"
MUTED = "#81877a"

def box(rect):
    return tuple(round(v * S) for v in rect)

def font(size, mono=False, bold=False):
    name = "consolab.ttf" if mono and bold else "consola.ttf" if mono else "msyhbd.ttc" if bold else "msyh.ttc"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / name), round(size * S))

def gradient(size, top, bottom):
    base = Image.linear_gradient("L").resize(size)
    return ImageOps.colorize(base, top, bottom).convert("RGBA")

canvas = gradient((W*S, H*S), "#1b1d19", "#090d0b")
draw = ImageDraw.Draw(canvas)

def text(at, value, size=20, fill=CREAM, mono=False, bold=False):
    draw.text((round(at[0]*S), round(at[1]*S)), value, font=font(size, mono, bold), fill=fill)

def line(points, fill, width=1):
    draw.line([(round(x*S), round(y*S)) for x,y in points], fill=fill, width=max(1,round(width*S)))

def rect(coords, fill, radius=0, outline=None, width=1):
    draw.rounded_rectangle(box(coords), radius=round(radius*S), fill=fill, outline=outline, width=max(1,round(width*S)))

def panel(bounds, top, bottom=None, radius=8, border="#55574b", shadow=8, bevel=True):
    global canvas, draw
    x,y,x2,y2 = bounds
    if shadow:
        shade=Image.new("RGBA",canvas.size)
        sd=ImageDraw.Draw(shade)
        sd.rounded_rectangle(box((x,y+shadow*.5,x2,y2+shadow*.5)), radius=int(radius*S), fill=(0,0,0,150))
        canvas=Image.alpha_composite(canvas,shade.filter(ImageFilter.GaussianBlur(shadow*S)))
    layer=gradient((round((x2-x)*S),round((y2-y)*S)),top,bottom or top)
    mask=Image.new("L",layer.size)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,layer.width-1,layer.height-1),radius=round(radius*S),fill=255)
    layer.putalpha(mask)
    canvas.alpha_composite(layer,(round(x*S),round(y*S)))
    draw=ImageDraw.Draw(canvas)
    rect(bounds,None,radius,border,1.3)
    if bevel:
        highlight=Image.new("RGBA",canvas.size)
        ImageDraw.Draw(highlight).rounded_rectangle(box((x+2,y+2,x2-2,y2-2)),radius=round(max(0,radius-2)*S),outline=(255,255,255,28),width=S)
        canvas=Image.alpha_composite(canvas,highlight)
        draw=ImageDraw.Draw(canvas)

def circle(center, radius, fill, outline=None, width=1):
    x,y=center
    draw.ellipse(box((x-radius,y-radius,x+radius,y+radius)),fill=fill,outline=outline,width=max(1,round(width*S)))

def screw(x,y):
    circle((x,y),9,"#111612","#41473d",1)
    circle((x-1,y-1),6,"#242923")
    line([(x-3.5,y-3.5),(x+3.5,y+3.5)],"#0c100c",2)
    line([(x-3.5,y+3.5),(x+3.5,y-3.5)],"#0c100c",2)

def led(x,y,label,on=True):
    circle((x,y),14,"#1a3024" if on else "#302921","#384437",1)
    circle((x,y),8,"#78d69b" if on else "#603c29")
    circle((x-2,y-3),3,"#b2f0c1" if on else "#865139")
    text((x-19,y+21),label,12,"#b1b49e",mono=True)

def key(bounds,label,active=False,size=18):
    x,y,x2,y2=bounds
    rect((x-1,y-1,x2+1,y2+5),"#141914",7)
    panel(bounds,"#ddd5bc" if active else "#c3bea8","#b4ad94",6,"#e5ddc5",2)
    rect((x+3,y+3,x2-3,y2-4),None,4,"#e6deca",.6)
    f=font(size,mono=False,bold=True)
    b=draw.textbbox((0,0),label,font=f)
    draw.text((round(((x+x2)/2-(b[2]-b[0])/S/2)*S),round(((y+y2)/2-size*.68)*S)),label,font=f,fill="#262c24")

def transport_key(x,y,symbol):
    key((x,y,x+71,y+49),"")
    if symbol=="play":
        draw.polygon([tuple(round(v*S) for v in p) for p in [(x+29,y+15),(x+29,y+33),(x+44,y+24)]],fill=INK)
    elif symbol=="stop":
        rect((x+29,y+17,x+42,y+30),INK,1)
    elif symbol=="pause":
        rect((x+29,y+16,x+34,y+31),INK)
        rect((x+39,y+16,x+44,y+31),INK)
    else:
        for dx in (0,11):
            draw.polygon([tuple(round(v*S) for v in p) for p in [(x+42-dx,y+16),(x+29-dx,y+24),(x+42-dx,y+32)]],fill=INK)

def waveform(filename,bounds,tint):
    x,y,x2,y2=bounds
    with wave.open(str(ROOT/"assets"/"audio"/filename),"rb") as src:
        data=struct.unpack("<"+"h"*(src.getnframes()*src.getnchannels()),src.readframes(src.getnframes()))
    count=240
    step=max(1,len(data)//count)
    peaks=[max(abs(v) for v in data[i*step:min(len(data),(i+1)*step)]) for i in range(count)]
    normal=max(peaks) or 1
    mid=(y+y2)/2
    line([(x,mid),(x2,mid)],"#88b996",.7)
    for i,peak in enumerate(peaks):
        xx=x+(i+.5)*(x2-x)/count
        height=max(1.2,(peak/normal)**.72*(y2-y))
        line([(xx,mid-height/2),(xx,mid+height/2)],tint,1.7)

# Chassis: nested lips, soft brushed finish, restrained wear.
panel((50,32,1870,1038),"#33382f","#21261f",26,"#51574a",20)
rect((58,40,1862,1030),None,21,"#11170f",3)
rect((66,48,1854,1022),None,17,"#4a5043",1)
rng=random.Random(124)
for _ in range(26000):
    x=rng.randrange(70*S,1850*S)
    y=rng.randrange(52*S,1018*S)
    base=canvas.getpixel((x,y))
    delta=rng.choice((-3,-2,2,3))
    draw.point((x,y),fill=tuple(max(0,min(255,c+delta)) for c in base[:3])+(255,))
for x,y in [(86,69),(1834,69),(86,1001),(1834,1001)]:
    screw(x,y)
text((108,67),"FIND ME",34,"#d7d1bb",mono=True,bold=True)
text((295,82),"S O U N D   R E C O N S T R U C T I O N   S Y S T E M",13,"#929985",mono=True)
text((1530,77),"01  /  门后",20,"#ccc7b0")
line([(108,116),(1812,116)],"#515647",1)

# Warm ivory CRT bezel and inset glass.
panel((108,146,1366,696),"#d4ceb7","#aaa78f",39,"#e6e1cc",12)
rect((116,154,1358,688),None,33,"#959780",2)
panel((130,168,1344,674),"#282f25","#141b14",28,"#5c6351",2)
rect((143,181,1331,661),"#030d08",19,"#101d12",2)
text((171,202),"> PLAYBACK  01",19,"#93dca8",mono=True)
text((1010,204),"CAM 01 / CORRIDOR",15,"#66967a",mono=True)
# The film still is taken from this project's own running demo, then graded for CRT.
source=ROOT/"artifacts"/"01_editing.png"
if source.exists():
    still=Image.open(source).convert("RGB").crop((54,150,1098,464))
    still=ImageEnhance.Contrast(ImageOps.grayscale(still)).enhance(1.22)
    still=ImageOps.colorize(still,"#030e08","#9bce9a").convert("RGBA")
    still=still.resize((1150*S,346*S),Image.Resampling.LANCZOS)
    canvas.alpha_composite(still,(162*S,258*S))
    draw=ImageDraw.Draw(canvas)
text((172,615),"隔着磨砂门，她只能听见门外的声音。",20,"#88c698")
text((1096,621),"00:00:00",16,"#6fc791",mono=True)
scanlines=Image.new("RGBA",canvas.size)
scan_draw=ImageDraw.Draw(scanlines)
for yy in range(183*S,659*S,4*S):
    scan_draw.line([(145*S,yy),(1329*S,yy)],fill=(0,0,0,90),width=S)
canvas=Image.alpha_composite(canvas,scanlines)
draw=ImageDraw.Draw(canvas)
# A narrow highlight catches the edge of the curved glass.
line([(163,191),(1284,191)],"#417050",.6)

# Tape transport, matching the reference's cream mechanical panel.
panel((1404,146,1812,696),"#d2cbb2","#b7b299",23,"#e2dcc5",12)
text((1435,171),"TAPE DRIVE / 01",17,"#393d31",mono=True,bold=True)
panel((1431,206,1785,414),"#171f17","#090f0b",13,"#6d735d",3)
for cx,angle in [(1524,.16),(1691,.81)]:
    circle((cx,305),68,"#282a20","#c5c5a8",4)
    circle((cx,305),62,None,"#777e65",1)
    for i in range(3):
        a=angle+i*math.tau/3
        line([(cx,305),(cx+math.cos(a)*61,305+math.sin(a)*61)],"#d2d0b4",7)
    circle((cx,305),18,"#d4d1b5","#b2b59a",1)
line([(1525,373),(1691,373)],"#797e65",2)
for x,sym in [(1437,"back"),(1525,"play"),(1613,"pause"),(1701,"stop")]:
    transport_key(x,439,sym)
line([(1436,516),(1780,516)],"#9fA18a",1)
text((1437,542),"RECONSTRUCT",15,"#535947",mono=True)
text((1435,569),"等待重组",31,"#303a2c",bold=True)
text((1437,635),"C-60  /  TYPE I",15,"#505744",mono=True)
circle((1761,642),6,"#9b683f")

# Audio editing bed: time ticks, full waveforms, natural-language descriptions.
text((110,735),"02  /  声音重组",22,"#d2d0b9",bold=True)
text((405,743),"拖动片段，改写她的判断。",17,"#9da48f")
text((1297,743),"AUDIO  /  A",14,"#a7ad96",mono=True)
panel((108,783,1476,955),"#111a13","#141e16",11,"#53604b",4)
for xx,label in [(129,"00:00"),(788,"00:02.5"),(1393,"00:05")]:
    text((xx,792),label,13,"#798f78",mono=True)
for xx in range(130,1455,33):
    line([(xx,811),(xx,816 if (xx-130)%132 else 820)],"#4e624f",1)
cards=[(128,828,785,930,"01 / 惊叫","门外 · 一声惊呼","gasp.wav",True),
       (797,828,1454,930,"02 / 滴答","门外 · 液体滴落","drips.wav",False)]
for x,y,x2,y2,title,caption,filename,selected in cards:
    panel((x,y,x2,y2),"#344738" if selected else "#27382c","#213328",5,"#c8cfac" if selected else "#657c61",4)
    rect((x+2,y+2,x2-2,y+28),"#bfc7a8" if selected else "#5a6d52",3)
    text((x+12,y+5),title,16,"#202c21" if selected else "#e1e0c7",bold=True)
    text((x2-63,y+7),"2.5 s",12,"#354b35" if selected else "#c1cdb1",mono=True)
    waveform(filename,(x+14,y+38,x2-14,y+69),"#99d5a0" if selected else "#7bb98b")
    text((x+12,y+77),caption,13,"#c1d0b5")
# The editing handle is an affordance, never an ordering button.
for xx in [773,1442]:
    for yy in [842,847,852]:
        circle((xx,yy),1,"#d0d4b9")
text((112,975),"按住素材拖动重排  ·  点击素材试听",15,"#a2aa92")
rect((773,827,776,932),"#d4ad65",1)

# Physical run / reset controls and understated status lamps.
led(1535,755,"PWR")
led(1600,755,"TAPE")
led(1665,755,"LINK")
led(1730,755,"WARN",False)
key((1520,827,1786,891),"放映",True,25)
draw.polygon([tuple(round(v*S) for v in p) for p in [(1594,847),(1594,870),(1610,858.5)]],fill=INK)
key((1520,910,1645,955),"复位",False,17)
key((1661,910,1786,955),"声音 开",False,17)
text((1520,978),"RUN / SPACE",13,"#a3a98e",mono=True)
text((108,1010),"M-01   SOUND EDITING DESK",12,"#7e8873",mono=True)
for yy,col in [(1007,"#c9964d"),(1013,"#ad733d"),(1019,"#835936")]:
    rect((449,yy,664,yy+3),col)
text((1466,1009),"FIND ME  /  SYSTEM 01",12,"#6e7c65",mono=True)
# Very fine grain unifies the hardware without sacrificing label readability.
canvas.convert("RGB").resize((W,H),Image.Resampling.LANCZOS).save(OUT/"retro_console_v1.png")
print(OUT/"retro_console_v1.png")
