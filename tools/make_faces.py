"""Pinta texturas de rosto em estilo anime (512x512 RGBA, fundo transparente) para as
cabeças procedurais. O shader da cabeça projeta a textura na frente do rosto."""
import os, math, random
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'OblitusLimbo', 'assets', 'faces')
S = 2048            # supersample
F = S / 512.0

def P(x, y):
    return (x * F, y * F)

def bezier(p0, p1, p2, n=24):
    return [((1-t)**2*p0[0] + 2*(1-t)*t*p1[0] + t*t*p2[0], (1-t)**2*p0[1] + 2*(1-t)*t*p1[1] + t*t*p2[1]) for t in (i/(n-1) for i in range(n))]

def stroke(d, pts, w, col):
    pts = [P(*p) for p in pts]
    for i in range(len(pts) - 1):
        ww = w * F * (0.35 + 0.65 * math.sin(math.pi * (i + 0.5) / (len(pts) - 1)))
        d.line([pts[i], pts[i + 1]], fill=col, width=max(1, int(ww)))
        r = ww / 2
        d.ellipse([pts[i][0]-r, pts[i][1]-r, pts[i][0]+r, pts[i][1]+r], fill=col)

def eye(img, cx, cy, side, c):
    """side: -1 olho esquerdo da imagem, +1 direito. c: dicionário de estilo."""
    d = ImageDraw.Draw(img)
    w, h = c.get('eye_w', 58), c.get('eye_h', 34)
    slant = c.get('slant', 4) * side          # canto externo mais alto
    narrow = c.get('narrow', 0)
    top = cy - h * 0.55 + narrow
    bot = cy + h * 0.45
    inner = cx - side * w * 0.5
    outer = cx + side * w * 0.5
    # esclera
    sclera = bezier((inner, cy + 2), (cx, top - 6), (outer, cy - slant)) + bezier((outer, cy - slant), (cx, bot + 2), (inner, cy + 2))[1:]
    d.polygon([P(*p) for p in sclera], fill=c.get('sclera', (245, 240, 236, 255)))
    # íris (cortada pela pálpebra superior via máscara)
    iris = Image.new('RGBA', img.size, (0, 0, 0, 0)); di = ImageDraw.Draw(iris)
    ir_w, ir_h = w * c.get('iris', 0.46), h * 0.95
    icx, icy = cx + side * c.get('iris_off', 0), cy + 1
    col = c['iris_col']
    dark = tuple(int(v * 0.25) for v in col[:3]) + (255,)
    for k in range(18):                       # gradiente escuro em cima, claro embaixo
        t = k / 17
        cc = tuple(int(dark[i] * (1 - t) + col[i] * t) for i in range(3)) + (255,)
        yy = icy - ir_h / 2 + t * ir_h * 0.55
        di.ellipse([P(icx - ir_w/2*(1-t*0.08), yy), P(icx + ir_w/2*(1-t*0.08), icy + ir_h/2)], fill=cc)
    di.ellipse([P(icx - ir_w/2, icy - ir_h/2), P(icx + ir_w/2, icy + ir_h/2)], outline=dark, width=int(2.5*F))
    if c.get('reptile_side') == side:
        di.ellipse([P(icx - 3, icy - ir_h*0.42), P(icx + 3, icy + ir_h*0.42)], fill=(10, 8, 4, 255))
    else:
        pw = ir_w * c.get('pupil', 0.42)
        di.ellipse([P(icx - pw/2, icy - pw*0.55), P(icx + pw/2, icy + pw*0.55)], fill=(12, 8, 10, 255))
    # brilhos
    di.ellipse([P(icx - ir_w*0.32, icy - ir_h*0.33), P(icx - ir_w*0.05, icy - ir_h*0.08)], fill=(255, 255, 255, 235))
    di.ellipse([P(icx + ir_w*0.12, icy + ir_h*0.12), P(icx + ir_w*0.26, icy + ir_h*0.26)], fill=(255, 255, 255, 170))
    if c.get('glow'):
        di.ellipse([P(icx - ir_w*0.3, icy - ir_h*0.1), P(icx + ir_w*0.3, icy + ir_h*0.35)], fill=tuple(min(255, int(v*1.3)) for v in col[:3]) + (90,))
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).polygon([P(*p) for p in sclera], fill=255)
    img.paste(iris, (0, 0), Image.composite(iris, Image.new('RGBA', img.size, (0, 0, 0, 0)), mask).split()[3])
    # pálpebra superior (traço grosso) + cílio externo
    lash = c.get('lash', (24, 16, 20, 255))
    upper = bezier((inner - side * 3, cy + 3), (cx, top - 9), (outer + side * 6, cy - slant - 4))
    stroke(d, upper, c.get('lash_w', 9), lash)
    stroke(d, [(outer, cy - slant - 2), (outer + side * 12, cy - slant - 9), (outer + side * 17, cy - slant - 9)], 4.5, lash)
    if c.get('fem'):
        stroke(d, [(outer - side * 4, cy - slant - 6), (outer + side * 8, cy - slant - 17)], 3.5, lash)
    # pálpebra inferior
    stroke(d, bezier((cx - side * w * 0.12, bot + 1), (cx + side * w * 0.25, bot + 3), (outer - side * 2, cy - slant + 6)), 2.6, lash[:3] + (170,))
    # dobra da pálpebra
    stroke(d, bezier((inner + side * 8, top - 6), (cx, top - 16 + narrow), (outer - side * 6, cy - slant - 14)), 1.6, lash[:3] + (110,))

def brow(d, cx, cy, side, c, angry=False):
    col = c.get('brow_col', c.get('lash', (30, 20, 20, 255)))
    tilt = c.get('brow_tilt', 0) + (10 if angry else 0)
    w = c.get('brow_w', 54)
    inner = (cx - side * w * 0.45, cy + tilt * 0.5)
    outer = (cx + side * w * 0.55, cy - 2 - tilt * 0.2)
    mid = (cx + side * 4, cy - 7 - (0 if angry else 3))
    stroke(d, bezier(inner, mid, outer), c.get('brow_thick', 5.5), col)

def face(name, c, expr='n'):
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ey = c.get('eye_y', 262)
    ex = c.get('eye_x', 72)
    angry = expr == 'a'
    cc = dict(c)
    if angry:
        cc['narrow'] = c.get('narrow', 0) + 6
    # bochechas / rubor
    if c.get('blush'):
        for s in (-1, 1):
            g = Image.new('RGBA', (S, S), (0, 0, 0, 0))
            ImageDraw.Draw(g).ellipse([P(256 + s*ex - 30, ey + 34), P(256 + s*ex + 30, ey + 52)], fill=c['blush'])
            img.alpha_composite(g.filter(ImageFilter.GaussianBlur(10 * F)))
    if c.get('scales_side'):
        s = c['scales_side']
        rnd = random.Random(7)
        for k in range(520):
            x = 256 + s * rnd.uniform(10, 170); y = rnd.uniform(140, 440)
            edge = 256 + s * (48 + 26 * math.sin(y / 33.0) + 14 * math.sin(y / 11.0))
            if (x - edge) * s < rnd.uniform(-6, 10): continue
            if abs(x - (256 + s*ex)) < 36 and abs(y - ey) < 24: continue
            if rnd.random() < 0.25: continue
            r = rnd.uniform(5, 9)
            sh = rnd.uniform(0.75, 1.15)
            d.ellipse([P(x - r, y - r*0.8), P(x + r, y + r*0.8)], fill=(int(58*sh), int(66*sh), int(52*sh), 225), outline=(22, 26, 20, 200), width=int(1.2*F))
            d.arc([P(x - r*0.7, y - r*0.6), P(x + r*0.7, y + r*0.4)], 200, 340, fill=(90, 110, 96, 200), width=int(1.2*F))
    for s in (-1, 1):
        if c.get('patch') == s:
            d.ellipse([P(256 + s*ex - 34, ey - 26), P(256 + s*ex + 34, ey + 26)], fill=(22, 18, 18, 255))
            stroke(d, [(256 + s*ex - 30, ey - 10), (256, ey - 70)], 4, (30, 24, 22, 255))
            stroke(d, [(256 + s*ex + 30, ey - 12), (256 + s*150, ey - 50)], 4, (30, 24, 22, 255))
            continue
        cs = dict(cc)
        if c.get('reptile_side') == s:
            cs['iris_col'] = (240, 190, 40); cs['glow'] = True
        eye(img, 256 + s * ex, ey, s, cs)
        brow(d, 256 + s * ex, ey - c.get('brow_gap', 40), s, c, angry)
    # nariz
    ny = c.get('nose_y', 318)
    stroke(d, [(256 + 3, ny - 10), (256 + 6, ny), (256 - 2, ny + 3)], 2.6, c.get('line', (120, 70, 60, 170)))
    # boca
    my = c.get('mouth_y', 352)
    mouth = c.get('mouth', 'neutral') if not angry else c.get('mouth_angry', 'frown')
    lc = c.get('lip', (110, 50, 50, 220))
    if mouth == 'neutral':
        stroke(d, bezier((256 - 15, my), (256, my + 2), (256 + 15, my)), 3, lc)
    elif mouth == 'frown':
        stroke(d, bezier((256 - 15, my + 3), (256, my - 3), (256 + 15, my + 3)), 3.2, lc)
    elif mouth == 'smirk':
        stroke(d, bezier((256 - 14, my + 1), (256 + 4, my + 3), (256 + 18, my - 5)), 3, lc)
    elif mouth in ('grin', 'fang'):
        teeth = bezier((256 - 26, my - 4), (256, my + 14), (256 + 26, my - 4)) + bezier((256 + 26, my - 4), (256, my - 2), (256 - 26, my - 4))
        d.polygon([P(*p) for p in teeth], fill=(250, 246, 240, 255), outline=(70, 20, 20, 255))
        stroke(d, bezier((256 - 28, my - 5), (256, my + 18), (256 + 28, my - 5)), 3, (70, 20, 20, 255))
        if mouth == 'fang':
            for s in (-1, 1):
                d.polygon([P(256 + s*14, my - 3), P(256 + s*20, my - 3), P(256 + s*16, my + 8)], fill=(255, 255, 255, 255), outline=(80, 30, 30, 255))
    elif mouth == 'tusks':
        stroke(d, bezier((256 - 22, my + 2), (256, my + 6), (256 + 22, my + 2)), 3.5, lc)
        for s in (-1, 1):
            d.polygon([P(256 + s*14, my + 2), P(256 + s*24, my + 2), P(256 + s*18, my - 18)], fill=(240, 232, 210, 255), outline=(60, 50, 40, 255))
    # curativo no nariz (Yuto: sinais de brigas recentes)
    if c.get('bandage'):
        bx0, by0 = 256 - 22, ny - 16
        d.rounded_rectangle([P(bx0, by0), P(bx0 + 44, by0 + 14)], radius=int(3 * F), fill=(236, 226, 206, 255), outline=(150, 130, 110, 255), width=int(1.5 * F))
        for k in range(3):
            xx = bx0 + 12 + k * 10
            stroke(d, [(xx, by0 + 3), (xx, by0 + 11)], 1.2, (190, 170, 150, 255))
    # sardas
    if c.get('freckles'):
        rnd = random.Random(3)
        for k in range(14):
            s = rnd.choice((-1, 1)); x = 256 + s * rnd.uniform(40, 95); y = ey + rnd.uniform(28, 55)
            d.ellipse([P(x - 2.2, y - 2.2), P(x + 2.2, y + 2.2)], fill=(90, 40, 30, 150))
    if c.get('scar'):
        stroke(d, c['scar'], 2.5, (130, 50, 50, 200))
    out = img.resize((512, 512), Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, f'{name}_{expr}.png'))

FACES = {
    'kiana':   dict(iris_col=(200, 20, 24), glow=True, fem=True, eye_w=60, eye_h=36, slant=3, lash=(20, 14, 18, 255), brow_col=(210, 214, 220, 255), brow_thick=4.5, line=(40, 60, 30, 170), lip=(40, 60, 30, 230), mouth='neutral'),
    'near':    dict(iris_col=(214, 160, 40), eye_w=56, eye_h=28, slant=6, narrow=3, lash=(16, 12, 14, 255), brow_col=(200, 200, 205, 255), brow_tilt=4),
    'calista': dict(iris_col=(70, 74, 64), fem=True, eye_w=56, eye_h=30, slant=5, narrow=2, lash=(30, 18, 14, 255), brow_col=(170, 70, 30, 255), brow_tilt=6, mouth='frown', lip=(150, 70, 70, 220)),
    'amnon':   dict(iris_col=(190, 196, 206), eye_w=58, eye_h=34, slant=2, lash=(18, 10, 12, 255), brow_col=(16, 10, 12, 255), freckles=True, line=(80, 20, 20, 200), lip=(70, 15, 15, 230), mouth='fang', mouth_angry='grin'),
    'darin':   dict(iris_col=(40, 150, 90), eye_w=58, eye_h=32, slant=3, lash=(30, 20, 14, 255), brow_col=(70, 44, 26, 255), mouth='smirk'),
    'viktor':  dict(iris_col=(110, 130, 160), eye_w=56, eye_h=28, slant=4, narrow=3, lash=(30, 30, 40, 255), brow_col=(200, 204, 214, 255), brow_tilt=2),
    'krauser': dict(iris_col=(80, 120, 180), eye_w=56, eye_h=28, slant=6, narrow=4, lash=(16, 12, 12, 255), brow_col=(30, 22, 18, 255), brow_tilt=8, reptile_side=1, scales_side=1, mouth='smirk', lip=(110, 60, 60, 220)),
    'darius':  dict(iris_col=(220, 190, 50), eye_w=48, eye_h=24, slant=-2, narrow=4, lash=(14, 12, 10, 255), brow_col=(20, 20, 16, 255), brow_thick=9, brow_tilt=10, mouth='tusks', mouth_angry='tusks', line=(40, 50, 30, 200), lip=(40, 40, 30, 230)),
    'mira':    dict(iris_col=(110, 100, 90), fem=True, eye_w=48, eye_h=22, narrow=5, lash=(60, 50, 50, 255), brow_col=(200, 200, 200, 255), patch=-1, mouth='smirk'),
    'rurik':   dict(iris_col=(90, 100, 110), eye_w=46, eye_h=22, narrow=4, lash=(40, 34, 30, 255), brow_col=(140, 134, 124, 255), brow_thick=8, mouth='frown', scar=[(170, 220), (205, 300)]),
    'man':     dict(iris_col=(90, 70, 50), eye_w=48, eye_h=24, narrow=2, lash=(30, 22, 18, 255), brow_thick=6),
    'woman':   dict(iris_col=(70, 90, 60), fem=True, eye_w=54, eye_h=30, lash=(26, 18, 16, 255), brow_col=(80, 50, 30, 255)),
    'yuto':    dict(iris_col=(232, 140, 40), eye_w=54, eye_h=26, slant=6, narrow=4, lash=(14, 12, 16, 255), brow_col=(20, 20, 28, 255), brow_thick=6, brow_tilt=3, mouth='neutral', bandage=True, lip=(120, 60, 50, 220)),
    'thug':    dict(iris_col=(60, 50, 40), eye_w=46, eye_h=22, narrow=5, lash=(20, 16, 14, 255), brow_thick=8, brow_tilt=8, mouth='frown', scar=[(300, 210), (330, 290)]),
}

if __name__ == '__main__':
    for n, c in FACES.items():
        face(n, c, 'n')
        face(n, c, 'a')
    print('rostos:', len(FACES) * 2)
