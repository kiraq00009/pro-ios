import json, math, sys
from PIL import Image, ImageDraw, ImageFilter
S = 1024
def grad(c1, c2):
    im = Image.new('RGB', (S, S)); px = im.load()
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * S - 2); px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return im
def glow(im, center, radius, color, alpha=100):
    g = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    d.ellipse([center[0]-radius, center[1]-radius, center[0]+radius, center[1]+radius], fill=color + (alpha,))
    return Image.alpha_composite(im.convert('RGBA'), g.filter(ImageFilter.GaussianBlur(120)))
def save(im, app):
    d = f'{app}/Assets.xcassets'
    im.convert('RGB').save(f'{d}/AppIcon.appiconset/icon-1024.png')
    open(f'{d}/AppIcon.appiconset/Contents.json', 'w').write(json.dumps({"images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": {"author": "xcode", "version": 1}}))
    open(f'{d}/Contents.json', 'w').write(json.dumps({"info": {"author": "xcode", "version": 1}}))
W = (255, 255, 255, 255)

def dawri():
    im = glow(grad((10, 44, 34), (3, 14, 12)), (760, 230), 320, (60, 235, 140), 110)
    d = ImageDraw.Draw(im); G = (255, 205, 80, 255)
    d.pieslice([312, 150, 712, 640], 0, 180, fill=G)            # الكأس
    d.rectangle([312, 250, 712, 395], fill=G)
    d.arc([200, 250, 400, 470], 90, 270, fill=G, width=44); d.arc([624, 250, 824, 470], 270, 90, fill=G, width=44)
    d.rectangle([482, 620, 542, 740], fill=G)
    d.rounded_rectangle([372, 730, 652, 800], 26, fill=G)
    d.rounded_rectangle([322, 800, 702, 860], 20, fill=(60, 235, 140, 255))
    return im
def player():
    im = glow(grad((70, 80, 220), (150, 60, 220)), (300, 240), 330, (200, 210, 255), 100)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([170, 250, 854, 700], 70, fill=W)
    d.rounded_rectangle([210, 290, 814, 660], 44, fill=(40, 34, 90, 255))
    d.polygon([(450, 380), (450, 570), (620, 475)], fill=W)
    d.rounded_rectangle([372, 760, 652, 806], 23, fill=W)
    d.rectangle([482, 700, 542, 770], fill=W)
    return im
def waraq():
    im = glow(grad((255, 110, 80), (200, 40, 60)), (280, 230), 330, (255, 220, 190), 100)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([300, 190, 760, 800], 50, fill=(255, 255, 255, 110))
    d.rounded_rectangle([250, 240, 710, 850], 50, fill=W)
    for i, w in enumerate([330, 330, 250, 330, 180]):
        d.rounded_rectangle([690 - w - 20, 330 + i * 86, 690 - 20, 366 + i * 86], 18, fill=(230, 70, 70, 255) if i == 0 else (210, 214, 224, 255))
    d.line([(300, 760), (360, 700), (420, 770), (500, 690)], fill=(60, 80, 200, 255), width=22, joint='curve')
    return im
def dera():
    im = glow(grad((8, 30, 46), (3, 10, 20)), (760, 230), 320, (50, 230, 175), 110)
    d = ImageDraw.Draw(im); A = (50, 230, 175, 255)
    pts = [(512, 140), (810, 245), (810, 530), (770, 665), (665, 790), (512, 880), (359, 790), (254, 665), (214, 530), (214, 245)]
    d.polygon(pts, fill=A)
    d.line([(370, 520), (475, 630), (670, 400)], fill=(4, 28, 34, 255), width=70, joint='curve')
    return im
def qafza():
    im = glow(grad((70, 50, 170), (30, 16, 70)), (512, 240), 340, (190, 150, 255), 110)
    d = ImageDraw.Draw(im)
    cols = [(52, 209, 191), (82, 153, 255), (158, 115, 255), (255, 107, 158)]
    k = 0
    for r in range(2):
        for c in range(2):
            x = 222 + c * 300; y = 222 + r * 300
            d.rounded_rectangle([x, y, x + 280, y + 280], 66, fill=cols[k] + (255,)); k += 1
    d.rounded_rectangle([522, 522, 802, 802], 66, fill=(255, 209, 77, 255))
    d.line([(362, 362), (662, 362), (662, 662)], fill=(255, 255, 255, 235), width=44, joint='curve')
    d.ellipse([318, 318, 406, 406], fill=W)
    return im
def shuaa():
    im = glow(grad((8, 14, 36), (3, 5, 14)), (300, 700), 300, (255, 90, 190), 90)
    im = glow(im, (760, 260), 280, (60, 240, 255), 90)
    d = ImageDraw.Draw(im); B = (64, 242, 255, 255)
    pts = [(150, 700), (512, 700), (512, 330), (874, 330)]
    d.line(pts, fill=(64, 242, 255, 90), width=110, joint='curve')
    d.line(pts, fill=B, width=52, joint='curve')
    d.line(pts, fill=W, width=18, joint='curve')
    d.line([(400, 812), (624, 588)], fill=W, width=46)
    d.line([(400, 442), (624, 218)], fill=W, width=46)
    d.ellipse([110, 660, 190, 740], fill=B)
    d.ellipse([804, 260, 944, 400], outline=(255, 90, 190, 255), width=30); d.ellipse([846, 302, 902, 358], fill=(255, 90, 190, 255))
    return im
def nard():
    im = glow(grad((12, 84, 66), (3, 28, 24)), (512, 430), 430, (250, 205, 100), 70)
    d = ImageDraw.Draw(im)
    A = (238, 199, 122, 255); R = (160, 55, 42, 255)
    d.polygon([(70, 1024), (270, 1024), (170, 560)], fill=A)
    d.polygon([(754, 1024), (954, 1024), (854, 560)], fill=R)
    d.polygon([(70, 0), (270, 0), (170, 464)], fill=R)
    d.polygon([(754, 0), (954, 0), (854, 464)], fill=A)
    d.rounded_rectangle([318, 250, 706, 638], radius=92, fill=(40, 30, 20, 120))
    d.rounded_rectangle([312, 232, 712, 632], radius=92, fill=(252, 248, 238, 255))
    for (x, y) in [(412, 332), (612, 332), (512, 432), (412, 532), (612, 532)]:
        d.ellipse([x - 38, y - 38, x + 38, y + 38], fill=(22, 24, 30, 255))
    d.ellipse([252, 690, 492, 930], fill=(250, 243, 224, 255), outline=(196, 176, 134, 255), width=16)
    d.ellipse([312, 750, 432, 870], outline=(214, 198, 160, 255), width=10)
    d.ellipse([532, 690, 772, 930], fill=(30, 31, 38, 255), outline=(120, 122, 134, 255), width=16)
    d.ellipse([592, 750, 712, 870], outline=(74, 76, 88, 255), width=10)
    return im
def maghara():
    im = glow(grad((26, 20, 48), (6, 5, 12)), (512, 560), 380, (255, 150, 50), 130)
    d = ImageDraw.Draw(im)
    S = (14, 12, 24, 255)
    d.polygon([(0, 1024), (0, 300), (150, 120), (300, 0), (0, 0)], fill=S)
    d.polygon([(1024, 1024), (1024, 300), (874, 120), (724, 0), (1024, 0)], fill=S)
    d.polygon([(0, 1024), (0, 820), (220, 900), (512, 860), (804, 900), (1024, 820), (1024, 1024)], fill=S)
    for (x, w, h) in [(330, 70, 190), (470, 90, 260), (640, 70, 170)]:
        d.polygon([(x, 0), (x + w, 0), (x + w // 2, h)], fill=S)
    d.ellipse([382, 470, 642, 730], fill=(255, 190, 80, 255))
    d.ellipse([432, 520, 592, 680], fill=(255, 240, 190, 255))
    d.polygon([(512, 300), (590, 520), (434, 520)], fill=(255, 170, 60, 255))
    d.rounded_rectangle([482, 700, 542, 900], radius=20, fill=(120, 76, 40, 255))
    return im
def shabaka():
    im = glow(grad((8, 20, 30), (3, 7, 12)), (512, 520), 420, (60, 200, 230), 110)
    d = ImageDraw.Draw(im)
    C = (70, 220, 245, 255); cx, cy = 512, 600
    # أقواس إشارة
    for i, r in enumerate([150, 300, 450]):
        col = (70, 220, 245, 255) if i < 3 else C
        d.arc([cx - r, cy - r, cx + r, cy + r], start=225, end=315, fill=col, width=46)
    d.ellipse([cx - 48, cy - 48, cx + 48, cy + 48], fill=C)
    # عقد شبكة فوق
    nodes = [(300, 250), (512, 180), (724, 250)]
    for (x, y) in nodes:
        d.line([(cx, cy - 10), (x, y)], fill=(70, 220, 245, 120), width=12)
    for (x, y) in nodes:
        d.ellipse([x - 40, y - 40, x + 40, y + 40], fill=(255, 255, 255, 255), outline=C, width=10)
    return im
def shifra():
    im = glow(grad((26, 18, 46), (6, 5, 14)), (512, 480), 420, (120, 90, 240), 120)
    d = ImageDraw.Draw(im)
    M = (80, 235, 180, 255)
    # قفل
    d.rounded_rectangle([332, 470, 692, 760], radius=60, fill=(245, 245, 250, 255))
    d.arc([372, 250, 652, 560], start=180, end=360, fill=M, width=66)
    d.rectangle([372, 405, 438, 500], fill=M); d.rectangle([586, 405, 652, 500], fill=M)
    d.ellipse([482, 560, 542, 620], fill=(40, 30, 70, 255))
    d.rectangle([503, 600, 521, 690], fill=(40, 30, 70, 255))
    # بتّات متطايرة
    import random as _r; _r.seed(9)
    for _ in range(26):
        x = _r.randint(120, 904); y = _r.randint(120, 900)
        if 300 < x < 720 and 230 < y < 780: continue
        d.text((x, y), _r.choice(['0', '1']), fill=(120, 230, 255, 200))
    return im

def _font(sz, bold=False):
    from PIL import ImageFont
    names = ["arialbd.ttf","ariblk.ttf","arial.ttf"] if bold else ["arial.ttf","arialbd.ttf"]
    for n in names:
        try: return ImageFont.truetype(n, sz)
        except: pass
    return ImageFont.load_default()

def sudoku():
    im = glow(grad((28, 36, 72), (8, 10, 26)), (512, 480), 420, (90, 130, 255), 110)
    d = ImageDraw.Draw(im)
    x0, y0, sz = 212, 212, 600; c = sz / 9
    d.rounded_rectangle([x0-16, y0-16, x0+sz+16, y0+sz+16], radius=40, fill=(245, 247, 255, 255))
    for i in range(10):
        w = 10 if i % 3 == 0 else 3
        col = (40, 60, 140, 255) if i % 3 == 0 else (170, 185, 230, 255)
        d.line([(x0+i*c, y0), (x0+i*c, y0+sz)], fill=col, width=w)
        d.line([(x0, y0+i*c), (x0+sz, y0+i*c)], fill=col, width=w)
    f = _font(66, True)
    nums = {(0,0):"5",(1,1):"3",(2,2):"7",(0,4):"9",(4,4):"2",(8,8):"1",(3,6):"6",(6,3):"8",(7,1):"4"}
    for (r,cc),n in nums.items():
        d.text((x0+cc*c+c/2, y0+r*c+c/2), n, fill=(40, 60, 140, 255), anchor="mm", font=f)
    return im

def algham():
    import math as _m
    im = glow(grad((40, 46, 60), (10, 12, 20)), (512, 480), 420, (255, 90, 70), 120)
    d = ImageDraw.Draw(im)
    for i in range(5):
        for j in range(5):
            x, y = 190+j*130, 190+i*130
            d.rounded_rectangle([x, y, x+118, y+118], radius=18, fill=(60, 68, 88, 255) if (i+j)%2 else (72, 82, 104, 255))
    cx, cy = 512, 512
    d.ellipse([cx-120, cy-120, cx+120, cy+120], fill=(20, 22, 30, 255))
    for a in range(0, 360, 45):
        x2, y2 = cx+_m.cos(_m.radians(a))*165, cy+_m.sin(_m.radians(a))*165
        d.line([(cx, cy), (x2, y2)], fill=(20, 22, 30, 255), width=26)
    d.ellipse([cx-40, cy-70, cx-4, cy-34], fill=(255, 255, 255, 230))
    return im

def damj():
    im = glow(grad((60, 50, 30), (22, 18, 10)), (512, 480), 420, (255, 200, 90), 120)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([180, 180, 844, 844], radius=46, fill=(70, 62, 48, 255))
    cols = {2:(238,228,218),512:(237,200,80),1024:(237,150,60),2048:(237,120,70)}
    vals = [[2,512],[1024,2048]]
    f = _font(92, True)
    for i in range(2):
        for j in range(2):
            v = vals[i][j]; x, y = 212+j*322, 212+i*322
            d.rounded_rectangle([x, y, x+300, y+300], radius=30, fill=cols[v]+(255,))
            col = (120, 110, 100, 255) if v <= 4 else (255, 255, 255, 255)
            d.text((x+150, y+150), str(v), fill=col, anchor="mm", font=f)
    return im

def katla():
    im = glow(grad((30, 24, 50), (10, 8, 18)), (512, 480), 420, (150, 120, 255), 110)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([170, 170, 854, 854], radius=44, fill=(36, 30, 56, 255))
    c = 76
    for i in range(8):
        for j in range(8):
            d.rounded_rectangle([190+j*c, 190+i*c, 190+j*c+66, 190+i*c+66], radius=10, fill=(48, 40, 72, 255))
    cells = {(2,2):(255,110,120),(2,3):(255,110,120),(3,2):(255,110,120),(1,5):(90,210,160),(2,5):(90,210,160),(3,5):(90,210,160),(5,1):(255,200,90),(5,2):(255,200,90),(6,1):(90,180,255),(6,2):(90,180,255),(6,3):(90,180,255),(5,5):(200,130,255),(5,6):(200,130,255)}
    for (i,j),col in cells.items():
        d.rounded_rectangle([190+j*c, 190+i*c, 190+j*c+66, 190+i*c+66], radius=10, fill=col+(255,))
    return im

def jawahir():
    im = glow(grad((40, 20, 60), (12, 8, 24)), (512, 500), 420, (255, 120, 220), 120)
    d = ImageDraw.Draw(im)
    cx, cy = 512, 520
    d.polygon([(cx-230, cy-120), (cx-150, cy-240), (cx+150, cy-240), (cx+230, cy-120), (cx, cy+260)], fill=(255, 90, 200, 255))
    d.polygon([(cx-230, cy-120), (cx, cy-120), (cx, cy+260)], fill=(255, 140, 220, 255))
    d.polygon([(cx-150, cy-240), (cx, cy-120), (cx-230, cy-120)], fill=(255, 180, 235, 255))
    d.polygon([(cx+150, cy-240), (cx, cy-120), (cx+230, cy-120)], fill=(220, 60, 170, 255))
    d.line([(cx-150, cy-240), (cx-230, cy-120)], fill=(255, 255, 255, 180), width=8)
    return im

def wassel():
    im = glow(grad((12, 30, 40), (4, 10, 16)), (512, 500), 420, (60, 220, 200), 110)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([180, 180, 844, 844], radius=44, fill=(14, 24, 34, 255))
    def dot(x, y, col): d.ellipse([x-46, y-46, x+46, y+46], fill=col)
    d.line([(300, 300), (300, 540), (540, 540), (720, 540), (720, 720)], fill=(255, 120, 90, 255), width=48, joint="curve")
    d.line([(720, 300), (480, 300), (480, 500), (300, 720)], fill=(90, 200, 255, 255), width=48, joint="curve")
    dot(300, 300, (255, 120, 90, 255)); dot(720, 720, (255, 120, 90, 255))
    dot(720, 300, (90, 200, 255, 255)); dot(300, 720, (90, 200, 255, 255))
    return im

def bixel():
    im = glow(grad((24, 30, 44), (8, 10, 18)), (512, 480), 420, (120, 200, 255), 110)
    d = ImageDraw.Draw(im); c = 90
    x0, y0 = 232, 232
    heart = [(1,2),(1,4),(2,1),(2,2),(2,3),(2,4),(2,5),(3,2),(3,3),(3,4),(4,3)]
    for i in range(6):
        for j in range(6):
            on = (i,j) in heart
            col = (255, 90, 120, 255) if on else (40, 48, 64, 255)
            d.rounded_rectangle([x0+j*c, y0+i*c, x0+j*c+80, y0+i*c+80], radius=10, fill=col)
    return im

def kalimat():
    im = glow(grad((20, 40, 36), (8, 16, 14)), (512, 480), 420, (90, 230, 170), 110)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([180, 180, 844, 844], radius=44, fill=(16, 30, 26, 255))
    f = _font(72)
    letters = list("كلماتبحرشمسقلمنجف")
    c = 128; idx = 0
    for i in range(5):
        for j in range(5):
            ch = letters[idx % len(letters)]; idx += 1
            on = (i+j) % 3 == 0
            if on: d.rounded_rectangle([210+j*c, 210+i*c, 210+j*c+116, 210+i*c+116], radius=16, fill=(90, 220, 160, 255))
            d.text((210+j*c+58, 210+i*c+58), ch, fill=(255,255,255,255) if on else (150,180,170,255), anchor="mm", font=f)
    return im

def solitaire():
    im = glow(grad((12, 50, 34), (4, 20, 14)), (512, 480), 440, (40, 180, 110), 110)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([260, 280, 560, 700], radius=36, fill=(250, 250, 248, 255), outline=(200,200,200,255), width=3)
    f = _font(150, True); fs = _font(80)
    d.text((410, 470), "A", fill=(20, 20, 24, 255), anchor="mm", font=f)
    d.text((410, 600), "\u2660", fill=(20, 20, 24, 255), anchor="mm", font=f)
    d.text((305, 335), "A", fill=(20,20,24,255), anchor="mm", font=fs)
    return im

def thakira():
    import math as _m
    im = glow(grad((44, 24, 54), (14, 8, 22)), (512, 480), 420, (200, 120, 255), 120)
    d = ImageDraw.Draw(im)
    # بطاقة يسار مكشوفة: نجمة ذهبيّة
    d.rounded_rectangle([200, 300, 468, 724], radius=34, fill=(250, 248, 255, 255))
    cx, cy, R, r = 334, 512, 92, 40
    pts = []
    for k in range(10):
        ang = _m.radians(-90 + k*36); rad = R if k%2==0 else r
        pts.append((cx+_m.cos(ang)*rad, cy+_m.sin(ang)*rad))
    d.polygon(pts, fill=(255, 190, 60, 255))
    # بطاقة يمين مقلوبة: ظهر بنفسجيّ بنقش
    d.rounded_rectangle([556, 300, 824, 724], radius=34, fill=(120, 70, 220, 255))
    d.rounded_rectangle([580, 324, 800, 700], radius=24, outline=(180, 150, 255, 255), width=8)
    for gx in range(620, 790, 48):
        for gy in range(360, 690, 48):
            d.ellipse([gx-10, gy-10, gx+10, gy+10], fill=(180, 150, 255, 200))
    return im

def film():
    im = glow(grad((40, 22, 8), (14, 8, 3)), (512, 480), 440, (255, 130, 30), 140)
    d = ImageDraw.Draw(im)
    OR = (255, 125, 20, 255)
    d.rounded_rectangle([210, 360, 814, 760], radius=40, fill=(26, 20, 14, 255), outline=OR, width=14)
    d.rectangle([210, 360, 814, 430], fill=OR)
    d.polygon([(250, 300), (320, 360), (380, 300), (310, 240)], fill=OR)
    for k in range(6):
        d.rounded_rectangle([250+k*96, 470, 250+k*96+70, 540], radius=8, fill=(255,255,255,40))
        d.rounded_rectangle([250+k*96, 630, 250+k*96+70, 700], radius=8, fill=(255,255,255,40))
    d.ellipse([456, 490, 568, 602], fill=OR)
    d.polygon([(500, 520), (500, 572), (548, 546)], fill=(26, 20, 14, 255))
    return im

if __name__ == '__main__':
    for name in sys.argv[1:]:
        save(globals()[name.lower()](), name)
    print('icons ok')
