# The App Store's screenshots: the app's own screens (drawn offscreen by the Debug build's -render-store, kept by the
# CI in refs/screens/ios-native as store/*.png) with a caption above each, in the app's type and colours.
#   git fetch origin refs/screens/ios-native && git archive FETCH_HEAD store | tar -x -C /tmp/raw
#   python3 store/compose.py /tmp/raw/store
# writes store/screenshots/iphone-6.9/*.jpg (1320 × 2868) and store/screenshots/ipad-13/*.jpg (2752 × 2064).
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW = sys.argv[1] if len(sys.argv) > 1 else "/tmp/raw/store"
HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "TheBetrayal", "Resources", "Fonts")
OUT = os.path.join(HERE, "screenshots")

SOOT, PEAT, DUSK = (9, 7, 10), (19, 13, 20), (29, 16, 32)
TALLOW, TALLOW2, BRASS, BRASS2 = (232, 208, 200), (175, 161, 152), (174, 98, 73), (230, 165, 140)

# the order on the store, each with its caption: a line in IM Fell and a smaller one beneath
PHONE = [
    ("oath", "Everyone swears an oath.", "Not everyone means it."),
    ("roles-forsworn", "A few of you are Forsworn.", "Your phone tells you, and no one else."),
    ("likely-open", "Party games for the Purse.", "Quizzes, guesses, words and more."),
    ("vote-mine", "Argue. Accuse. Vote.", "Each round, the table votes someone out."),
    ("night-forsworn-picked", "By night, the Forsworn choose.", "Everyone taps too, so no one can tell who."),
    ("end-winner", "Find every Forsworn.", "Or watch them take the Purse."),
]
TV = [
    ("lobby-host", "Your TV becomes the show.", "Friends join in the app, or scan the code."),
    ("quiz-open", "Everyone answers on their own phone.", "The TV keeps the table together."),
    ("talk", "The Reckoning.", "A few minutes of debate, then a secret vote."),
    ("reveal-exiled", "The exile is unmasked.", "Loyal or Forsworn, the table finds out."),
    ("dawn-revealed", "Dawn brings the night’s victim.", "Last words, then back to the table."),
    ("end-host", "Who takes the Purse?", "The Loyal, or the ones who lied all night."),
]

def font(name, size): return ImageFont.truetype(os.path.join(FONTS, name), size)

def backdrop(w, h):
    # the app's backdrop: soot, with a dusk glow above and a faint brass one below
    im = Image.new("RGB", (w, h), SOOT)
    glow = Image.new("RGB", (w, h), SOOT)
    d = ImageDraw.Draw(glow)
    d.ellipse((-w * 0.3, -h * 0.25, w * 1.3, h * 0.45), fill=DUSK)
    d.ellipse((w * 0.1, h * 0.75, w * 0.9, h * 1.25), fill=(40, 20, 22))
    return Image.blend(im, glow.filter(ImageFilter.GaussianBlur(w * 0.12)), 0.9)

def centred(d, text, f, y, w, fill):
    x0, y0, x1, y1 = d.textbbox((0, 0), text, font=f)
    d.text(((w - (x1 - x0)) / 2 - x0, y), text, font=f, fill=fill)
    return y + (y1 - y0)

def framed(shot, w, radius):
    # the screen, with rounded corners and a hairline in the brass, as the app draws its cards
    h = round(shot.height * w / shot.width)
    shot = shot.convert("RGB").resize((w, h), Image.LANCZOS)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=255)
    edge = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((0, 0, w - 1, h - 1), radius, outline=BRASS + (150,), width=max(2, w // 400))
    return shot, mask, edge

def compose(raw, title, sub, size, shot_w, top, out):
    W, H = size
    im = backdrop(W, H)
    d = ImageDraw.Draw(im)
    y = centred(d, title, font("IMFellDWPica-Roman.ttf", round(W * (0.07 if W < H else 0.04))), top, W, TALLOW)
    y = centred(d, sub, font("AlegreyaSans-Regular.ttf", round(W * (0.037 if W < H else 0.022))), y + round(W * (0.035 if W < H else 0.018)), W, BRASS2)
    shot, mask, edge = framed(Image.open(raw), shot_w, round(shot_w * 0.045))
    x, sy = (W - shot_w) // 2, y + round(W * (0.05 if W < H else 0.022))
    im.paste(shot, (x, sy), mask)
    im.paste(edge, (x, sy), edge)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out, "JPEG", quality=92, optimize=True)
    print(out, im.size)

def find(prefix, name):
    for f in sorted(os.listdir(RAW)):
        if f.startswith(prefix) and f.endswith("-" + name + ".png"): return os.path.join(RAW, f)
    sys.exit("missing " + prefix + " " + name + " in " + RAW)

for i, (name, title, sub) in enumerate(PHONE, 1):
    compose(find("phone-", name), title, sub, (1320, 2868), 1110, 150, os.path.join(OUT, "iphone-6.9", f"{i:02d}-{name}.jpg"))
for i, (name, title, sub) in enumerate(TV, 1):
    compose(find("tv-", name), title, sub, (2752, 2064), 2160, 110, os.path.join(OUT, "ipad-13", f"{i:02d}-{name}.jpg"))
