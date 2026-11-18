import random
from PIL import Image, ImageDraw, ImageFont
W,H=480,270
F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',8)
F7=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',7)
BG=(6,7,14); PANEL=(16,19,36); EDGE=(55,138,221); TXT=(220,226,236); DIM=(120,128,145)
GREEN=(99,190,90); RED=(226,75,74); YEL=(250,199,117); BLUE=(55,138,221); LBLUE=(133,183,235)
def base():
    im=Image.new('RGB',(W,H),BG); d=ImageDraw.Draw(im); random.seed(5)
    for _ in range(140):
        x,y=random.randrange(W),random.randrange(H); v=random.choice([90,140,200]); d.point((x,y),(v,v,v+20))
    # planet
    for r,c in [(46,(60,30,40)),(42,(120,60,55)),(36,(160,85,70)),(26,(190,110,85))]:
        d.ellipse([300-r,120-r,300+r,120+r],fill=c)
    d.ellipse([268,80,330,128],fill=(205,130,100))
    # own ship
    s1=Image.open('s1.png').convert('RGB').crop((2,32,326,150)); s1=s1.resize((int(s1.width*.6),int(s1.height*.6)),Image.NEAREST)
    m=Image.new('L',s1.size,0); px=s1.load(); mp=m.load()
    for y in range(s1.height):
        for x in range(s1.width):
            r,g,b=px[x,y]; mp[x,y]=0 if (r,g,b) in [(11,13,26),(255,255,255)] or (r<16 and g<18 and b<30) else 255
    im.paste(s1,(70,96),m)
    s5=Image.open('s5.png').convert('RGB').crop((0,212,360,322)).transpose(Image.FLIP_LEFT_RIGHT); s5=s5.resize((int(s5.width*.5),int(s5.height*.5)),Image.NEAREST)
    m=Image.new('L',s5.size,0); px=s5.load(); mp=m.load()
    for y in range(s5.height):
        for x in range(s5.width):
            r,g,b=px[x,y]; mp[x,y]=0 if (r<16 and g<18 and b<30) or (r,g,b)==(255,255,255) else 255
    sh=Image.new('RGB',(200,80),(226,75,74)); sm=Image.new('L',(200,80),0); ImageDraw.Draw(sm).ellipse([0,0,199,79],outline=140,width=2,fill=40)
    im.paste(sh,(282,74),sm); im.paste(s5,(292,86),m)
    # crosshair on enemy room
    d.rectangle([363,95,381,113],outline=RED); d.line([372,89,372,95],fill=RED); d.line([372,113,372,119],fill=RED)
    # top: hull
    d.rectangle([4,4,152,30],fill=PANEL,outline=EDGE); d.text((8,6),"HÜLLE",fill=TXT,font=F)
    for i in range(24): d.rectangle([40+i*4.5,8,43+i*4.5,14],fill=GREEN if i<18 else (40,48,60))
    for i in range(4): d.ellipse([8+i*11,19,16+i*11,27],fill=BLUE if i<3 else (40,48,60),outline=LBLUE)
    d.text((56,19),"SCHILDE",fill=LBLUE,font=F7)
    # resources
    d.rectangle([156,4,312,18],fill=PANEL,outline=EDGE)
    for x,c,t in [(160,YEL,"12"),(198,(180,178,169),"34"),(236,RED,"8"),(274,(93,202,165),"3")]:
        d.rectangle([x,8,x+6,14],fill=c); d.text((x+9,6),t,fill=TXT,font=F)
    d.text((158,20),"Treibst. Rohst. Raketen Drohnen",fill=DIM,font=F7)
    d.rectangle([4,32,70,52],fill=PANEL,outline=EDGE); d.text((8,34),"O2  100%",fill=LBLUE,font=F7); d.text((8,43),"AUSW. 25%",fill=TXT,font=F7)
    # jump + pause
    d.rectangle([340,4,400,24],fill=(40,30,8),outline=YEL); d.text((350,6),"SPRUNG",fill=YEL,font=F); d.rectangle([344,17,396,21],outline=YEL); d.rectangle([345,18,378,20],fill=YEL)
    d.rectangle([448,4,474,24],fill=PANEL,outline=EDGE); d.rectangle([456,8,459,20],fill=TXT); d.rectangle([463,8,466,20],fill=TXT)
    d.rectangle([406,4,442,24],fill=PANEL,outline=EDGE); d.text((412,9),"KARTE",fill=TXT,font=F7)
    # crew list
    crew=[("Rhea",(24,95,165),1.0),("Brakka",(186,117,23),0.7),("Kix",(99,153,34),0.9),("K-7",(212,217,222),1.0),("Ylen",(127,119,221),0.5),("Petr",(136,135,128),1.0)]
    for i,(n,c,hp) in enumerate(crew):
        y=58+i*17; d.rectangle([4,y,70,y+14],fill=PANEL,outline=EDGE if i!=1 else YEL)
        d.rectangle([7,y+3,14,y+10],fill=c); d.text((18,y+1),n,fill=TXT,font=F7); d.rectangle([18,y+10,18+int(48*hp),y+12],fill=GREEN if hp>.6 else YEL)
    # reactor + systems
    d.rectangle([4,170,126,266],fill=PANEL,outline=EDGE)
    for i in range(16): d.rectangle([8,252-i*5,16,255-i*5],fill=GREEN if i<6 else (40,48,60))
    d.text((6,258),"",fill=TXT,font=F7)
    syst=[("S",BLUE,3,4),("A",(216,90,48),2,3),("+",GREEN,1,2),("O2",LBLUE,1,1),("W",RED,4,4)]
    for k,(l,c,on,mx) in enumerate(syst):
        x=26+k*20
        for j in range(mx): d.rectangle([x,240-j*7,x+12,245-j*7],fill=GREEN if j<on else (40,48,60),outline=(60,70,90))
        d.ellipse([x-1,249,x+13,263],fill=c); d.text((x+(3 if len(l)==1 else 0),251),l,fill=(10,11,22),font=F7)
    # weapons
    d.rectangle([130,214,352,266],fill=PANEL,outline=EDGE); d.text((134,216),"WAFFEN",fill=TXT,font=F)
    for i,(n,ch) in enumerate([("Laser II",1.0),("Ionen",0.6),("Rakete",0.3),("Strahl",0.0)]):
        x=134+i*54; d.rectangle([x,228,x+50,262],fill=(24,28,48),outline=YEL if ch>=1 else (70,80,100))
        d.text((x+4,231),n,fill=TXT if ch>0 else DIM,font=F7); d.rectangle([x+4,252,x+46,257],outline=(70,80,100)); d.rectangle([x+5,253,x+5+int(40*ch),256],fill=YEL if ch>=1 else GREEN)
    d.rectangle([356,214,428,266],fill=PANEL,outline=EDGE); d.text((360,216),"DROHNEN",fill=TXT,font=F)
    d.rectangle([360,228,424,262],fill=(24,28,48),outline=(70,80,100)); d.text((364,231),"Abwehr I",fill=TXT,font=F7)
    d.rectangle([432,214,476,266],fill=PANEL,outline=EDGE); d.text((436,216),"TÜREN",fill=TXT,font=F7); d.rectangle([438,230,470,246],outline=LBLUE); d.text((441,234),"ALLE",fill=LBLUE,font=F7); d.text((436,250),"SCHLEUSE",fill=RED,font=F7)
    return im,d
im,d=base(); im.resize((W*3,H*3),Image.NEAREST).save('/home/claude/driftline/art/pixel/hud_kampf_pixel.png')
im,d=base()
ov=Image.new('RGB',(W,H),(0,0,0)); im=Image.blend(im,ov,0.55); d=ImageDraw.Draw(im)
d.rectangle([84,40,396,206],fill=(14,18,34),outline=EDGE); d.rectangle([86,42,394,204],outline=(30,50,80))
d.rectangle([92,48,150,90],fill=(30,40,60)); 
for r,c in [(18,(150,190,220)),(14,(200,225,240))]: d.ellipse([121-r,69-r,121+r,69+r],fill=c)
txt=["Die Sensoren erfassen Lebenszeichen auf einem","nahen Eisplaneten. In der Datenbank findet sich","kein passender Eintrag."]
for i,t in enumerate(txt): d.text((158,50+i*11),t,fill=TXT,font=F7)
opts=[("1. Außenteam landen lassen",TXT,(24,28,48)),("2. [Veyari] Signal aus dem Orbit analysieren",LBLUE,(16,40,70)),("3. Weiterfliegen",TXT,(24,28,48))]
for i,(t,c,bg) in enumerate(opts):
    y=104+i*30; d.rectangle([92,y,388,y+24],fill=bg,outline=(70,80,100) if i!=1 else LBLUE); d.text((100,y+8),t,fill=c,font=F)
d.rectangle([340,192,392,202],fill=(16,40,70)); d.text((346,193),"PAUSIERT",fill=LBLUE,font=F7)
im.resize((W*3,H*3),Image.NEAREST).save('/home/claude/driftline/art/pixel/hud_ereignis_pixel.png')
