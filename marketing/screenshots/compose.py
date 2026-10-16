"""Builds the 6.9" App Store panels (1320x2868) from raw simulator captures.

    python3 marketing/screenshots/compose.py

Raw captures live in raw-v2/ (xcrun simctl io <device> screenshot ...).
Output: out/<locale>/01.png ... 06.png
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw-v2")
OUT = os.path.join(HERE, "out")
W, H = 1320, 2868

CREAM = (250, 248, 245)
INK = (42, 46, 43)
SOFT = (106, 114, 106)
GREEN = (78, 125, 63)
BLOBS = [((255, 222, 196), (-260, 1900, 760)), ((214, 233, 200), (900, 1500, 620)),
         ((255, 236, 179), (980, -180, 520))]

ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
JAPANESE = "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc"

PANELS = ["hatch.png", "tab0.png", "onb5.png", "tab2.png", "tab3.png", "onb0.png"]

# (title, highlighted part of the title, subtitle) per panel, per locale.
CAPTIONS = {
    "en-US": [
        ("Hatch your own avocado buddy", "avocado buddy", "A cozy pet that grows with your healthy habits"),
        ("Lose weight without the bloat", "without the bloat", "Calories and triggers, checked for every meal"),
        ("Know what upsets your stomach", "your stomach", "Dairy, gluten, FODMAPs and more"),
        ("Small daily goals, big wins", "big wins", "Earn XP and seeds for every healthy choice"),
        ("Grow your own little garden", "little garden", "Unlock pots and decor as you go"),
        ("Snap a meal, get real calories", "real calories", "From the USDA database, never guessed"),
    ],
    "es-ES": [
        ("Haz nacer a tu propio aguacate", "aguacate", "Una mascota que crece con tus hábitos saludables"),
        ("Adelgaza sin hinchazón", "sin hinchazón", "Calorías y alérgenos revisados en cada comida"),
        ("Descubre qué le sienta mal a tu estómago", "tu estómago", "Lácteos, gluten, FODMAP y más"),
        ("Pequeñas metas, grandes logros", "grandes logros", "Gana XP y semillas con cada elección sana"),
        ("Haz crecer tu propio jardín", "jardín", "Desbloquea macetas y decoración"),
        ("Fotografía tu comida", "tu comida", "Calorías reales de la base de datos del USDA"),
    ],
    "fr-FR": [
        ("Faites éclore votre avocat", "votre avocat", "Un compagnon qui grandit avec vos bonnes habitudes"),
        ("Maigrir sans ballonnements", "sans ballonnements", "Calories et allergènes vérifiés à chaque repas"),
        ("Repérez ce qui dérange votre ventre", "votre ventre", "Lactose, gluten, FODMAP et plus encore"),
        ("Petits objectifs, grandes victoires", "grandes victoires", "Gagnez de l'XP et des graines à chaque bon choix"),
        ("Faites pousser votre jardin", "votre jardin", "Débloquez des pots et de la déco"),
        ("Photographiez votre repas", "votre repas", "De vraies calories issues de la base USDA"),
    ],
    "de-DE": [
        ("Lass deine Avocado schlüpfen", "Avocado", "Ein Begleiter, der mit deinen gesunden Gewohnheiten wächst"),
        ("Abnehmen ohne Blähbauch", "ohne Blähbauch", "Kalorien und Allergene bei jeder Mahlzeit geprüft"),
        ("Finde heraus, was dein Bauch nicht mag", "dein Bauch", "Laktose, Gluten, FODMAPs und mehr"),
        ("Kleine Ziele, große Erfolge", "große Erfolge", "Sammle XP und Samen für jede gesunde Wahl"),
        ("Lass deinen Garten wachsen", "Garten", "Schalte Töpfe und Deko frei"),
        ("Fotografiere dein Essen", "dein Essen", "Echte Kalorien aus der USDA-Datenbank"),
    ],
    "pt-BR": [
        ("Faça nascer o seu abacate", "abacate", "Um bichinho que cresce com seus hábitos saudáveis"),
        ("Emagreça sem inchaço", "sem inchaço", "Calorias e alérgenos checados em cada refeição"),
        ("Descubra o que faz mal à sua barriga", "sua barriga", "Lactose, glúten, FODMAPs e mais"),
        ("Metas pequenas, grandes conquistas", "grandes conquistas", "Ganhe XP e sementes a cada escolha saudável"),
        ("Faça seu jardim crescer", "jardim", "Desbloqueie vasos e decoração"),
        ("Fotografe sua refeição", "sua refeição", "Calorias reais da base de dados do USDA"),
    ],
    "ja": [
        ("アボカドの相棒を|育てよう", "アボカドの相棒", "健康的な習慣で一緒に成長するペット"),
        ("お腹に優しくダイエット", "お腹に優しく", "毎食のカロリーとアレルゲンをチェック"),
        ("お腹に合わない|食べ物がわかる", "わかる", "乳製品、グルテン、FODMAPなど"),
        ("小さな目標で大きな成果", "大きな成果", "健康的な選択でXPと種を獲得"),
        ("自分だけのお庭を|育てよう", "お庭", "植木鉢やインテリアをアンロック"),
        ("食事を撮るだけ", "撮るだけ", "USDAデータベースの正確なカロリー"),
    ],
}


def font(locale, size, weight):
    if locale == "ja":
        return ImageFont.truetype(JAPANESE, size)
    f = ImageFont.truetype(ROUNDED, size)
    f.set_variation_by_name(weight)
    return f


def tokens(text, locale):
    """Words for Latin scripts; single characters for Japanese (no spaces)."""
    if locale == "ja":
        return list(text)
    out = []
    for i, w in enumerate(text.split(" ")):
        out.append(w if i == 0 else " " + w)
    return out


def balanced(draw, text, f, max_w, locale):
    """Two lines of similar width beat a long line and an orphan word."""
    lines = wrap(draw, text, f, max_w, locale)
    if len(lines) != 2:
        return lines
    toks = tokens(text, locale)
    best, best_w = lines, max(draw.textlength(l, font=f) for l in lines)
    for i in range(1, len(toks)):
        a, b = "".join(toks[:i]), "".join(toks[i:]).lstrip()
        w = max(draw.textlength(a, font=f), draw.textlength(b, font=f))
        if w <= max_w and w < best_w:
            best, best_w = [a, b], w
    return best


def wrap(draw, text, f, max_w, locale):
    lines, cur = [], ""
    for t in tokens(text, locale):
        trial = cur + t
        if cur and draw.textlength(trial, font=f) > max_w:
            lines.append(cur)
            cur = t.lstrip()
        else:
            cur = trial
    if cur:
        lines.append(cur)
    return lines


def draw_title(draw, title, highlight, locale, top):
    size = 104 if locale != "ja" else 96
    f = font(locale, size, b"Bold")
    # "|" marks a forced line break (Japanese has no spaces to break on).
    forced = title.split("|") if "|" in title else None
    title = title.replace("|", "")
    while True:
        lines = forced or balanced(draw, title, f, W - 180, locale)
        too_wide = any(draw.textlength(l, font=f) > W - 140 for l in lines)
        if (len(lines) <= 2 and not too_wide) or size <= 72:
            break
        size -= 6
        f = font(locale, size, b"Bold")
    hl_start = title.find(highlight)
    hl_end = hl_start + len(highlight) if hl_start >= 0 else -1
    y, consumed = top, 0
    for line in lines:
        # Map this line back to its character offsets in the title.
        idx = title.find(line, consumed)
        idx = consumed if idx < 0 else idx
        x = (W - draw.textlength(line, font=f)) / 2
        for k, ch in enumerate(line):
            pos = idx + k
            color = GREEN if hl_start <= pos < hl_end else INK
            draw.text((x, y), ch, font=f, fill=color)
            x += draw.textlength(ch, font=f)
        consumed = idx + len(line)
        y += int(size * 1.18)
    return y


def panel(raw_path, caption, locale):
    title, highlight, sub = caption
    # Soft pastel blobs, blurred, so the cream isn't flat. Drawn straight onto
    # the cream (no alpha layer), otherwise the blur drags in dark edges.
    img = Image.new("RGB", (W, H), CREAM)
    bd = ImageDraw.Draw(img)
    for color, (cx, cy, r) in BLOBS:
        mixed = tuple(int(c * 0.6 + k * 0.4) for c, k in zip(color, CREAM))
        bd.ellipse((cx, cy, cx + r, cy + r), fill=mixed)
    img = img.filter(ImageFilter.GaussianBlur(140))

    draw = ImageDraw.Draw(img)
    y = draw_title(draw, title, highlight, locale, 190)
    sf = font(locale, 50 if locale != "ja" else 46, b"Medium")
    for line in wrap(draw, sub, sf, W - 220, locale):
        x = (W - draw.textlength(line, font=sf)) / 2
        draw.text((x, y + 18), line, font=sf, fill=SOFT)
        y += 64

    # The phone: the capture with rounded corners, a slim frame and a shadow.
    shot = Image.open(raw_path).convert("RGB")
    pw = 1000
    ph = int(shot.height * pw / shot.width)
    shot = shot.resize((pw, ph), Image.LANCZOS)
    top = max(y + 90, 700)
    radius, bezel = 110, 22
    frame = Image.new("RGBA", (pw + bezel * 2, ph + bezel * 2), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame.width - 1, frame.height - 1),
                                            radius=radius + bezel, fill=(32, 34, 33, 255))
    mask = Image.new("L", (pw, ph), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, pw - 1, ph - 1), radius=radius, fill=255)
    frame.paste(shot, (bezel, bezel), mask)

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    left = (W - frame.width) // 2
    ImageDraw.Draw(shadow).rounded_rectangle((left + 10, top + 40, left + frame.width - 10, top + frame.height + 40),
                                             radius=radius + bezel, fill=(60, 50, 30, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(45))
    img.paste(shadow, (0, 0), shadow)
    img.paste(frame, (left, top), frame)
    return img


def main():
    for locale, caps in CAPTIONS.items():
        d = os.path.join(OUT, locale)
        os.makedirs(d, exist_ok=True)
        for i, (raw, cap) in enumerate(zip(PANELS, caps), 1):
            panel(os.path.join(RAW, raw), cap, locale).save(os.path.join(d, f"{i:02d}.png"), optimize=True)
        print("built", locale)


if __name__ == "__main__":
    main()
