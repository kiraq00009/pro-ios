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
if __name__ == '__main__':
    for name in sys.argv[1:]:
        save(globals()[name.lower()](), name)
    print('icons ok')
