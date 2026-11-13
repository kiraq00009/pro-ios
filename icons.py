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
if __name__ == '__main__':
    for name in sys.argv[1:]:
        save(globals()[name.lower()](), name)
    print('icons ok')
