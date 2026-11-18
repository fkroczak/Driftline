import subprocess
from PIL import Image, ImageDraw, ImageFont
W,H,S=480,270,0.75
subprocess.run(['rsvg-convert','-w',str(W),'-h',str(H),'map.svg','-o','low.png'],check=True)
im = Image.open('low.png').convert('RGB').quantize(colors=220, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
d = ImageDraw.Draw(im)
f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 8)
def tag(x, y, text, fg, bg, border):
    w = d.textlength(text, font=f)
    d.rectangle([x-3, y-2, x+w+3, y+10], fill=bg, outline=border)
    d.text((x, y), text, fill=fg, font=f)
d.rectangle([0,0,W-1,15], fill=(10,11,22)); d.line([0,15,W-1,15], fill=(55,138,221))
d.text((6,3), "TREIBSTOFF 12", fill=(250,199,117), font=f)
d.text((110,3), "ROHSTOFFE 34", fill=(180,178,169), font=f)
d.text((300,3), "SPRÜNGE 7/10", fill=(240,149,149), font=f)
d.text((400,3), "SEKTOR 2", fill=(133,183,235), font=f)
tag(229, 222, "NOTRUF", (252,235,235), (80,19,19), (226,75,74))
tag(297, 190, "HÄNDLER", (250,238,218), (65,36,2), (239,159,39))
tag(418, 150, "AUSGANG", (230,241,251), (4,44,83), (133,183,235))
tag(412, 70, "BOSS", (252,235,235), (80,19,19), (226,75,74))
tag(8, 252, "JÄGERFRONT", (252,235,235), (80,19,19), (226,75,74))
x,y=160,94
lines=["Unerforschtes System","1 Treibstoff · Sprung möglich"]
w=max(d.textlength(t,font=f) for t in lines)
d.rectangle([x-4,y-3,x+w+4,y+22], fill=(10,11,22), outline=(250,199,117))
d.text((x,y),lines[0],fill=(255,255,255),font=f); d.text((x,y+11),lines[1],fill=(250,199,117),font=f)
d.line([x+w+4,y+22,262,122], fill=(250,199,117))
im.resize((W*3,H*3), Image.NEAREST).save('/home/claude/driftline/art/pixel/sprungkarte_pixel.png')
