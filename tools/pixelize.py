import sys, re, subprocess
from PIL import Image, ImageDraw
src, out, w, h, scale, ncol, bgmode = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]), sys.argv[7]
svg = open(src).read()
# shadow-only and figure-only variants (shadows are elements tagged opacity 0.35/0.4/0.5 black)
shadow_re = re.compile(r'<(ellipse|path|circle)[^>]*fill="#000"[^>]*opacity="0\.(35|4|5)"[^>]*/>')
fig = shadow_re.sub('', svg)
shadows = re.findall(shadow_re.pattern.replace('(ellipse|path|circle)', '(?:ellipse|path|circle)').replace('(35|4|5)', '(?:35|4|5)'), svg)
open('_fig.svg','w').write(fig)
subprocess.run(['rsvg-convert','-w',str(w),'-h',str(h),'_fig.svg','-o','_fig.png'],check=True)
# shadow svg: keep transforms by blanking everything else is hard; instead render full minus figure alpha
subprocess.run(['rsvg-convert','-w',str(w),'-h',str(h),src,'-o','_full.png'],check=True)
f = Image.open('_fig.png').convert('RGBA'); full = Image.open('_full.png').convert('RGBA')
W,H = f.size
fa = f.getchannel('A'); fula = full.getchannel('A')
# quantize figure colors
rgb = Image.new('RGB', f.size, (0,0,0)); rgb.paste(f, mask=fa)
q = rgb.quantize(colors=ncol, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
fp = fa.load(); sp = fula.load()
# background
bg = Image.new('RGB', (W,H))
bp = bg.load(); qp = q.load()
for y in range(H):
    for x in range(W):
        if bgmode == 'floor':
            c = (26,30,46)
            if x % 12 == 0 or y % 12 == 0: c = (34,39,58)
        else:
            c = (7,8,15)
        bp[x,y] = c
import random; random.seed(3)
if bgmode == 'space':
    for _ in range(W*H//300):
        x,y = random.randrange(W), random.randrange(H)
        v = random.choice([140,180,230]); bp[x,y]=(v,v,v)
out_im = bg.copy(); op = out_im.load()
for y in range(H):
    for x in range(W):
        if fp[x,y] < 128 and sp[x,y] > 20:  # shadow
            r,g,b = op[x,y]; op[x,y] = (int(r*0.62),int(g*0.62),int(b*0.66))
OUT = (10,11,22)
for y in range(H):
    for x in range(W):
        if fp[x,y] >= 128:
            op[x,y] = qp[x,y]
        else:
            n = any(0<=x+dx<W and 0<=y+dy<H and fp[x+dx,y+dy]>=128 for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)))
            if n: op[x,y] = OUT
out_im = out_im.resize((W*scale,H*scale), Image.NEAREST)
out_im.save(out)
print(out, out_im.size)
