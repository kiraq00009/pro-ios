"""ينسخ ميزان (الويب) إلى Mizan/web داخل تطبيق الآيفون: خطوط محليّة + جسر native.js + بلا تكبير."""
import os, re, shutil, sys
SRC = r"C:\Users\w\.gemini\antigravity\scratch\dawwirli_vip\mizan"
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = os.path.join(HERE, "Mizan", "web")
FONTS = sys.argv[1] if len(sys.argv) > 1 else None
keep_fonts = os.path.join(DST, "fonts")
tmpf = None
if os.path.isdir(keep_fonts) and not FONTS:
    tmpf = keep_fonts + "_keep"; shutil.copytree(keep_fonts, tmpf, dirs_exist_ok=True)
if os.path.isdir(DST): shutil.rmtree(DST)
os.makedirs(DST)
for d in ("css", "js"): shutil.copytree(os.path.join(SRC, d), os.path.join(DST, d))
for f in ("icon.svg", "icon-180.png"): shutil.copy(os.path.join(SRC, f), DST)
os.makedirs(os.path.join(DST, "fonts"))
if FONTS:
    for f in os.listdir(FONTS):
        if f.endswith(".ttf"): shutil.copy(os.path.join(FONTS, f), os.path.join(DST, "fonts", f))
elif tmpf:
    shutil.copytree(tmpf, os.path.join(DST, "fonts"), dirs_exist_ok=True); shutil.rmtree(tmpf)
w = {"Regular": 400, "Medium": 500, "SemiBold": 600, "Bold": 700}
open(os.path.join(DST, "css", "fonts.css"), "w", encoding="utf-8").write("".join(
    "@font-face{font-family:'IBM Plex Sans Arabic';font-weight:%d;font-style:normal;font-display:swap;src:url(../fonts/IBMPlexSansArabic-%s.ttf) format('truetype')}\n" % (v, k) for k, v in w.items()))
shutil.copy(os.path.join(HERE, "Mizan", "native.js"), os.path.join(DST, "js", "native.js"))
s = open(os.path.join(SRC, "index.html"), encoding="utf-8").read()
s = re.sub(r'\s*<link rel="preconnect"[^>]*>', "", s)
s = re.sub(r'\s*<link href="https://fonts.googleapis.com[^>]*>', "", s)
s = re.sub(r'\s*<link rel="manifest"[^>]*>', "", s)
s = s.replace('initial-scale=1, viewport-fit=cover', 'initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover')
s = s.replace('<link rel="stylesheet" href="css/app.css?v=1">', '<link rel="stylesheet" href="css/fonts.css">\n<link rel="stylesheet" href="css/app.css?v=1">')
s = s.replace('<script src="js/app.js?v=1"></script>', '<script src="js/app.js?v=1"></script>\n<script src="js/native.js"></script>')
assert "native.js" in s and "fonts.css" in s and "googleapis" not in s
open(os.path.join(DST, "index.html"), "w", encoding="utf-8").write(s)
print("web ->", DST, sum(len(f) for _, _, f in os.walk(DST)), "files")
