"""Copia os assets usados de AssetsParaOJogo/ para OblitusLimbo/assets/,
reduzindo texturas para tamanhos adequados a uma GTX 1050 (3 GB)."""
import os, shutil, glob, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'AssetsParaOJogo')
DST = os.path.join(ROOT, 'OblitusLimbo', 'assets')

def find_dir(*parts):
    pat = os.path.join(SRC, *parts)
    hits = [p for p in glob.glob(pat.replace('[', '[[]'), recursive=True) if os.path.isdir(p)]
    if not hits:
        raise SystemExit('não encontrado: ' + pat)
    return hits[0]

def copy_tex(src, dst, max_size):
    im = Image.open(src)
    if max(im.size) > max_size:
        im = im.resize((max_size, max_size) if im.size[0] == im.size[1] else
                       (max_size, int(im.size[1] * max_size / im.size[0])), Image.LANCZOS)
    im.save(dst, optimize=True)

def tex_limit(name, default):
    n = name.lower()
    if 'basecolor' in n or 'diffuse' in n or n.startswith(('bark_', 'leaves', 'leaf_')):
        return default
    return min(default, 1024)

def copy_dir(src_dir, dst_dir, max_tex=1024, only=None):
    os.makedirs(dst_dir, exist_ok=True)
    n = 0
    for f in os.listdir(src_dir):
        s = os.path.join(src_dir, f)
        if not os.path.isfile(s) or f.lower() == 'desktop.ini':
            continue
        ext = os.path.splitext(f)[1].lower()
        if only and ext in ('.gltf', '.bin') and os.path.splitext(f)[0] not in only:
            continue
        d = os.path.join(dst_dir, f)
        if ext in ('.gltf', '.bin', '.glb'):
            shutil.copy2(s, d); n += 1
        elif ext in ('.png', '.jpg'):
            copy_tex(s, d, tex_limit(f, max_tex)); n += 1
    print(f'{os.path.relpath(dst_dir, ROOT)}: {n} arquivos')

def main():
    # personagens (trajes + partes modulares)
    mod = find_dir('Modular Character Outfits*', '**', 'glTF (Godot-Unreal)')
    copy_dir(os.path.join(mod, 'Outfits'), os.path.join(DST, 'characters'), 2048)
    copy_dir(os.path.join(mod, 'Modular Parts'), os.path.join(DST, 'characters'), 2048)
    tex = find_dir('Modular Character Outfits*', '**', 'Textures')
    for f in ['Peasant/T_Peasant_2_BaseColor.png', 'Ranger/T_Ranger_3_BaseColor.png']:
        copy_tex(os.path.join(tex, f), os.path.join(DST, 'characters', os.path.basename(f)), 2048)
    # animações e manequins
    os.makedirs(os.path.join(DST, 'anims'), exist_ok=True)
    for pat in ['Universal Animation Library[[]Standard]/**/Unreal-Godot/UAL1_Standard.glb',
                'Universal Animation Library 2*/**/Unreal-Godot/UAL2_Standard.glb',
                'Universal Animation Library 2*/**/Female Mannequin/Unreal-Godot/Mannequin_F.glb']:
        f = glob.glob(os.path.join(SRC, pat), recursive=True)[0]
        shutil.copy2(f, os.path.join(DST, 'anims', os.path.basename(f)))
    print('anims ok')
    copy_dir(find_dir('Medieval Village MegaKit*', '**', 'glTF'), os.path.join(DST, 'village'), 1024)
    copy_dir(find_dir('Stylized Nature MegaKit*', 'glTF'), os.path.join(DST, 'nature'), 1024)
    copy_dir(find_dir('KayKit_Dungeon*', '**', 'Assets', 'gltf'), os.path.join(DST, 'dungeon'), 1024)
    copy_dir(find_dir('KayKit_FantasyWeapons*', '**', 'Assets', 'gltf'), os.path.join(DST, 'weapons'), 1024)
    # retratos (artes do autor)
    pd = os.path.join(ROOT, 'versao_web', 'assets', 'portraits')
    os.makedirs(os.path.join(DST, 'portraits'), exist_ok=True)
    for f in os.listdir(pd):
        if f.endswith('.jpg'):
            shutil.copy2(os.path.join(pd, f), os.path.join(DST, 'portraits', f))
    print('portraits ok')

if __name__ == '__main__' and 'stylized' not in sys.argv:
    main()


# ---------------------------------------------------------------------------
#  Texturas estilizadas CC0 (Lynocs, "Stylized Texture Pack") baixadas em downloads/
# ---------------------------------------------------------------------------
def prepare_stylized_textures():
    import numpy as np
    from PIL import Image
    dl = os.path.join(ROOT, "downloads")
    out = os.path.join(ROOT, "OblitusLimbo", "assets", "textures")
    os.makedirs(out, exist_ok=True)

    def hue_shift(im, target_hue, keep=0.15):
        a = np.asarray(im.convert("HSV")).astype(np.float32)
        a[..., 0] = (a[..., 0] * keep + target_hue * 255.0 * (1 - keep)) % 255
        return Image.fromarray(a.astype(np.uint8), "HSV").convert("RGB")

    jobs = [
        ("Fall_Ground/Fall Ground/1/1", "valley_ground", None),
        ("Mystical/Mystical/4/4", "domain_ground", None),
        ("Flesh/Flesh/7/7", "limbo_ground", 0.78),
        ("Flesh/Flesh/3/3", "limbo_heart", 0.8),
        ("Burned_Earth/Burned Earth/1/1", "scorch", None),
    ]
    for src, name, hue in jobs:
        base = os.path.join(dl, "x_" + src)
        im = Image.open(base + "_diffuseOriginal.bmp").convert("RGB")
        if hue is not None:
            im = hue_shift(im, hue)
        im.save(os.path.join(out, name + ".png"))
        nrm = base + "_normal.bmp"
        if os.path.exists(nrm):
            Image.open(nrm).convert("RGB").resize((512, 512)).save(os.path.join(out, name + "_n.png"))
        print("textura", name)
    font = os.path.join(dl, "KaushanScript-Regular.ttf")
    if os.path.exists(font):
        shutil.copy(font, os.path.join(ROOT, "OblitusLimbo", "assets", "fonts", "KaushanScript-Regular.ttf"))
        print("fonte KaushanScript")


if __name__ == "__main__" and "stylized" in sys.argv:
    prepare_stylized_textures()
