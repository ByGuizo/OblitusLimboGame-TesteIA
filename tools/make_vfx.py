"""Gera as texturas de efeitos no estilo anime (Naruto Storm): fumaça cel-shaded com contorno,
chamas em línguas, estrelas de impacto, notas musicais, cristais, anéis de choque, rachaduras,
linhas de velocidade e o arco de corte. Saída: OblitusLimbo/assets/vfx/*.png
Uso: python tools/make_vfx.py
"""
import os
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "OblitusLimbo", "assets", "vfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(3)


def grid(n):
    y, x = np.mgrid[0:n, 0:n]
    return (x + 0.5) / n * 2 - 1, (y + 0.5) / n * 2 - 1


def vnoise(n, freq, seed=0):
    """Ruído de valor suave e repetível (n x n)."""
    r = np.random.default_rng(seed)
    g = r.random((freq + 1, freq + 1))
    g[-1, :] = g[0, :]
    g[:, -1] = g[:, 0]
    xs = np.linspace(0, freq, n, endpoint=False)
    xi = xs.astype(int)
    xf = xs - xi
    xf = xf * xf * (3 - 2 * xf)
    a = g[np.ix_(xi, xi)]
    b = g[np.ix_(xi, xi + 1)]
    c = g[np.ix_(xi + 1, xi)]
    d = g[np.ix_(xi + 1, xi + 1)]
    top = a + (b - a) * xf[None, :]
    bot = c + (d - c) * xf[None, :]
    return top + (bot - top) * xf[:, None]


def fbm(n, seed=0, octaves=4, base=4):
    s = np.zeros((n, n))
    amp = 0.5
    for o in range(octaves):
        s += vnoise(n, base * (2 ** o), seed + o) * amp
        amp *= 0.5
    return s / (1 - 0.5 ** octaves)


def save_rgba(a, name):
    a = np.clip(a, 0, 1)
    Image.fromarray((a * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name))
    print("vfx", name)


def outline_mask(mask, px=2):
    im = Image.fromarray((mask * 255).astype(np.uint8))
    dil = np.asarray(im.filter(ImageFilter.MaxFilter(px * 2 + 1))) / 255.0
    return np.clip(dil - mask, 0, 1)


# ---------------------------------------------------------------------------
#  Fumaça cel-shaded (flipbook 4x4): nuvem que cresce e se desfaz, 2 tons + contorno
# ---------------------------------------------------------------------------
def toon_smoke():
    n = 128
    sheet = np.zeros((n * 4, n * 4, 4))
    x, y = grid(n)
    base = fbm(n, 11, 4, 3)
    for k in range(16):
        t = k / 15.0
        r = np.sqrt(x * x + y * y)
        # bolhas: raio modulado por ruído angular
        ang = np.arctan2(y, x)
        lobes = 0.12 * np.sin(ang * 5 + 1.3) + 0.08 * np.sin(ang * 9 + 0.4)
        rad = (0.45 + 0.35 * t) * (1 + lobes)
        shape = (rad - r) * 3 + (base - 0.5) * 0.9
        thr = -0.05 + t * 0.85                      # erosão ao longo da vida
        erosion = fbm(n, 30 + k // 4, 3, 5)
        mask = ((shape > 0) & (erosion > thr * 0.95)).astype(float)
        mask = np.asarray(Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.ModeFilter(5))) / 255.0
        # 2 tons: claro em cima/esquerda, sombra embaixo/direita
        light = ((x * -0.5 + y * -0.8 + base * 0.6) > -0.15).astype(float)
        col = 0.62 + 0.38 * light
        line = outline_mask(mask, 2)
        rgb = np.stack([col, col, col], -1)
        rgb = rgb * (1 - line[..., None]) + 0.18 * line[..., None]
        a = np.clip(mask + line, 0, 1)
        tile = np.concatenate([rgb, a[..., None]], -1)
        gx, gy = k % 4, k // 4
        sheet[gy * n:(gy + 1) * n, gx * n:(gx + 1) * n] = tile
    save_rgba(sheet, "toon_smoke.png")


# ---------------------------------------------------------------------------
#  Chama em línguas (flipbook 4x4): núcleo claro, borda dura (para blend aditivo)
# ---------------------------------------------------------------------------
def flame():
    n = 128
    sheet = np.zeros((n * 4, n * 4, 4))
    x, y = grid(n)
    for k in range(16):
        t = k / 15.0
        nz = fbm(n, 50 + k, 4, 4)
        # gota alongada para cima, deslocada pelo ruído
        yy = y + 0.25
        width = 0.55 * (1 - np.clip((-yy + 0.6) / 1.6, 0, 1)) * (1 - t * 0.5)
        sx = x + (nz - 0.5) * 0.45 * (yy < 0.4)
        shape = width - np.abs(sx) * (1.0 + np.clip(-yy, 0, 2) * 0.6) + (nz - 0.5) * 0.35
        shape -= np.clip(yy - 0.55, 0, 1) * 2
        shape -= t * 0.25
        m1 = (shape > 0.0).astype(float)
        m2 = (shape > 0.12).astype(float)
        m3 = (shape > 0.24).astype(float)
        val = 0.45 * m1 + 0.3 * m2 + 0.25 * m3
        rgb = np.stack([val, val, val], -1)
        tile = np.concatenate([rgb, m1[..., None]], -1)
        gx, gy = k % 4, k // 4
        sheet[gy * n:(gy + 1) * n, gx * n:(gx + 1) * n] = tile
    save_rgba(sheet, "flame.png")


# ---------------------------------------------------------------------------
#  Estrelas / faíscas / impacto
# ---------------------------------------------------------------------------
def star(points=4, n=128, name="spark_star.png", sharp=7.0, core=0.18):
    x, y = grid(n)
    r = np.sqrt(x * x + y * y) + 1e-6
    ang = np.arctan2(y, x)
    spikes = np.abs(np.cos(ang * points / 2.0)) ** sharp
    shape = np.clip(1 - r / (0.25 + 0.75 * spikes), 0, 1)
    glow = np.clip(1 - r / core, 0, 1) ** 0.6
    a = np.clip(shape ** 1.2 + glow, 0, 1)
    rgb = np.ones((n, n, 3)) * np.clip(0.75 + glow[..., None] * 0.5, 0, 1)
    save_rgba(np.concatenate([rgb, a[..., None]], -1), name)


def impact_burst(n=256):
    """Explosão de impacto de mangá: estrela irregular de muitas pontas + linhas radiais."""
    x, y = grid(n)
    r = np.sqrt(x * x + y * y) + 1e-6
    ang = np.arctan2(y, x)
    r2 = np.random.default_rng(9)
    prof = np.zeros_like(ang)
    for i in range(14):
        a0 = r2.random() * 2 * np.pi
        w = 0.08 + r2.random() * 0.12
        l = 0.55 + r2.random() * 0.45
        d = np.abs((ang - a0 + np.pi) % (2 * np.pi) - np.pi)
        prof = np.maximum(prof, l * np.clip(1 - d / w, 0, 1))
    body = np.clip(0.32 + prof * 0.68 - r, 0, 1)
    m = (body > 0).astype(float)
    inner = (r < 0.22 + prof * 0.25).astype(float)
    val = 0.6 + 0.4 * inner
    rgb = np.stack([val, val, val], -1)
    save_rgba(np.concatenate([rgb, m[..., None]], -1), "impact_burst.png")


def glow_soft(n=128):
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    a = np.clip(1 - r, 0, 1) ** 2.2
    save_rgba(np.concatenate([np.ones((n, n, 3)), a[..., None]], -1), "glow_soft.png")


# ---------------------------------------------------------------------------
#  Nota musical (Kiana), cristal de gelo, pétala
# ---------------------------------------------------------------------------
def note(n=128):
    im = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(im)
    # colcheia dupla
    d.ellipse((18, 82, 52, 106), fill=255)
    d.ellipse((70, 70, 104, 94), fill=255)
    d.rectangle((46, 24, 54, 94), fill=255)
    d.rectangle((98, 12, 106, 82), fill=255)
    d.polygon([(46, 24), (106, 12), (106, 30), (46, 42)], fill=255)
    a = np.asarray(im.filter(ImageFilter.GaussianBlur(0.8))) / 255.0
    line = outline_mask((a > 0.5).astype(float), 3)
    rgb = np.ones((n, n, 3)) * (1 - line[..., None] * 0.7)
    save_rgba(np.concatenate([rgb, np.clip(a + line, 0, 1)[..., None]], -1), "note.png")


def ice_shard(n=128):
    im = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(im)
    d.polygon([(64, 4), (88, 60), (70, 124), (44, 70)], fill=255)
    d.polygon([(64, 4), (70, 124), (60, 70)], fill=170)
    a = (np.asarray(im) > 0).astype(float)
    val = np.asarray(im) / 255.0
    rgb = np.stack([val * 0.85 + 0.15] * 3, -1)
    save_rgba(np.concatenate([rgb, a[..., None]], -1), "ice_shard.png")


# ---------------------------------------------------------------------------
#  Anel de choque, rachaduras (decal), linhas de velocidade, arco de corte
# ---------------------------------------------------------------------------
def shock_ring(n=256):
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    wob = 0.04 * np.sin(ang * 7) + 0.03 * np.sin(ang * 13 + 1)
    band = np.clip(1 - np.abs(r - 0.82 - wob) / (0.07 + 0.05 * np.sin(ang * 5) ** 2), 0, 1)
    m = (band > 0.15).astype(float)
    core = (band > 0.6).astype(float)
    val = 0.65 + 0.35 * core
    rgb = np.stack([val] * 3, -1)
    save_rgba(np.concatenate([rgb, m[..., None]], -1), "shock_ring.png")


def cracks(n=512):
    im = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(im)
    r2 = np.random.default_rng(21)
    c = n / 2
    for i in range(11):
        ang = i / 11 * 2 * math.pi + r2.random() * 0.4
        px, py = c, c
        length = n * (0.25 + r2.random() * 0.22)
        steps = 9
        w = 9
        for s in range(steps):
            ang += (r2.random() - 0.5) * 0.7
            nx = px + math.cos(ang) * length / steps
            ny = py + math.sin(ang) * length / steps
            d.line((px, py, nx, ny), fill=255, width=max(1, int(w)))
            if r2.random() < 0.3:
                ba = ang + (r2.random() - 0.5) * 1.6
                d.line((nx, ny, nx + math.cos(ba) * 30, ny + math.sin(ba) * 30), fill=255, width=max(1, int(w * 0.5)))
            px, py = nx, ny
            w *= 0.82
    d.ellipse((c - 26, c - 26, c + 26, c + 26), fill=255)
    a = np.asarray(im.filter(ImageFilter.GaussianBlur(1.0))) / 255.0
    glow = np.asarray(im.filter(ImageFilter.GaussianBlur(7))) / 255.0
    # canal R = rachadura (escura), G = brilho em volta (para a versão incandescente)
    out = np.stack([a, np.clip(glow * 1.5, 0, 1), np.zeros_like(a), np.clip(a + glow * 0.6, 0, 1)], -1)
    save_rgba(out, "cracks.png")


def speed_lines(n=512):
    x, y = grid(n)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    r2 = np.random.default_rng(5)
    lines = np.zeros_like(r)
    for i in range(90):
        a0 = r2.random() * 2 * np.pi
        w = 0.004 + r2.random() * 0.012
        start = 0.35 + r2.random() * 0.35
        d = np.abs((ang - a0 + np.pi) % (2 * np.pi) - np.pi)
        lines = np.maximum(lines, np.clip(1 - d / w, 0, 1) * np.clip((r - start) * 4, 0, 1))
    a = (lines > 0.3).astype(float)
    save_rgba(np.concatenate([np.ones((n, n, 3)), a[..., None]], -1), "speed_lines.png")


def slash_arc(n=256):
    """Arco de corte de anime (UV: x ao longo do arco, y espessura) com bordas erodidas."""
    w, h = n, n // 4
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx + 0.5) / w
    v = (yy + 0.5) / h
    thick = np.sin(u * np.pi) ** 0.7
    edge = np.abs(v - 0.5) * 2
    nz = fbm(w, 77, 3, 6)[:h, :]
    m = ((edge < thick * (0.85 + (nz - 0.5) * 0.5)) & (u > 0.02)).astype(float)
    core = ((edge < thick * 0.35)).astype(float) * m
    val = 0.6 + 0.4 * core
    a = m * np.clip(u * 3, 0, 1)
    save_rgba(np.concatenate([np.stack([val] * 3, -1), a[..., None]], -1), "slash_arc.png")


def aura_noise(n=256):
    nz = fbm(n, 101, 5, 4)
    rgb = np.stack([nz] * 3, -1)
    save_rgba(np.concatenate([rgb, np.ones((n, n, 1))], -1), "aura_noise.png")


if __name__ == "__main__":
    toon_smoke()
    flame()
    star(4, name="spark_star.png")
    star(6, name="spark_star6.png", sharp=10.0, core=0.12)
    impact_burst()
    glow_soft()
    note()
    ice_shard()
    shock_ring()
    cracks()
    speed_lines()
    slash_arc()
    aura_noise()
