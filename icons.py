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
if __name__ == '__main__':
    for name in sys.argv[1:]:
        save(globals()[name.lower()](), name)
    print('icons ok')
