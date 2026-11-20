"""Keelbreak Pixel-Pipeline: SVG -> Zielauflösung -> Palette -> Kontur -> Schatten -> x4."""
import subprocess, os, tempfile
import numpy as np
from PIL import Image

OUTLINE = "#0A0B16"
SPACE = "#07080F"

PALETTE_HEX = [
    # Rumpf-Grau
    "#E6EAF0", "#C4CAD3", "#A9B0BB", "#8E97A4", "#747D8A", "#5A6370", "#424A56", "#2A2F3A", "#1A1E27",
    # Bodenfliesen
    "#363E58", "#2B3249", "#20263A", "#161B2B",
    # Kontur
    OUTLINE,
    # Blau
    "#D3E6F8", "#85B7EB", "#378ADD", "#185FA5", "#0E3A66",
    # Türkis
    "#DDF5EC", "#9FE1CB", "#5DCAA5", "#0F6E56", "#08402F",
    # Grün
    "#E4F0D0", "#C0DD97", "#639922", "#3B6D11", "#22400A",
    # Orange
    "#FDE6BF", "#FAC775", "#EF9F27", "#854F0B", "#4F2E05",
    # Rot
    "#F7C1C1", "#E24B4A", "#A32D2D", "#5E1919",
    # Koralle
    "#F9C9B6", "#F0997B", "#D85A30", "#8A3519",
    # Violett
    "#CECBF6", "#A6A0EA", "#7F77DD", "#534AB7", "#26215C",
    # Pink
    "#FBE3EB", "#F4C0D1", "#D4537E", "#8A2E4F",
    # Braun
    "#D9A867", "#B07A3C", "#7F4C1E", "#5E3614", "#3A2009",
    # Haut
    "#F2C9AE", "#E2AC8B", "#C58A6A", "#9A6448", "#6E4430",
    # Weiß
    "#FFFFFF",
]


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


PAL = np.array([hex2rgb(h) for h in PALETTE_HEX], dtype=np.float64)


def _lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ M.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    L = 116 * f[..., 1] - 16
    a = 500 * (f[..., 0] - f[..., 1])
    b = 200 * (f[..., 1] - f[..., 2])
    return np.stack([L, a, b], -1)


PAL_LAB = _lab(PAL)


def render_svg(svg_text, w, h, scale, tmpdir=None):
    tmpdir = tmpdir or tempfile.mkdtemp(prefix="keelbreak_")
    os.makedirs(tmpdir, exist_ok=True)
    src = os.path.join(tmpdir, "src.svg")
    out = os.path.join(tmpdir, "hi.png")
    with open(src, "w") as f:
        f.write(svg_text)
    subprocess.run(["rsvg-convert", "-w", str(w * scale), "-h", str(h * scale), "-o", out, src], check=True)
    return Image.open(out).convert("RGBA")


def downscale(hi, w, h):
    """Flächenmittel (Box) mit vormultipliziertem Alpha."""
    a = np.asarray(hi, dtype=np.float64)
    s = a.shape[0] // h
    rgb = a[..., :3] * (a[..., 3:4] / 255.0)
    rgb = rgb.reshape(h, s, w, s, 3).mean(axis=(1, 3))
    al = a[..., 3].reshape(h, s, w, s).mean(axis=(1, 3))
    with np.errstate(invalid="ignore", divide="ignore"):
        rgb = np.where(al[..., None] > 0, rgb / (al[..., None] / 255.0), 0)
    return np.clip(rgb, 0, 255), al


def quantize(rgb, alpha):
    lab = _lab(rgb)
    d = ((lab[..., None, :] - PAL_LAB[None, None]) ** 2).sum(-1)
    idx = d.argmin(-1)
    out = PAL[idx]
    opaque = alpha >= 127.5  # Alpha bei 50 % hart abschneiden
    return out, opaque


def add_outline(rgb, opaque):
    """1-px-Kontur (8er-Nachbarschaft) außen um die Figur."""
    h, w = opaque.shape
    pad = np.pad(opaque, 1)
    ring = np.zeros_like(opaque)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ring |= pad[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
    ring &= ~opaque
    rgb = rgb.copy()
    rgb[ring] = hex2rgb(OUTLINE)
    return rgb, opaque | ring


def shift(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    out[dy:, dx:] = mask[:h - dy, :w - dx]
    return out


def compose(rgb, opaque, shadow_off):
    """RGBA mit weichem Schlagschatten unten rechts (Kern 40 %, Rand 20 %)."""
    h, w = opaque.shape
    core = shift(opaque, shadow_off, shadow_off) & ~opaque
    pad = np.pad(shift(opaque, shadow_off, shadow_off), 1)
    grow = np.zeros_like(opaque)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if abs(dx) + abs(dy) == 1:
                grow |= pad[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
    fringe = grow & ~core & ~opaque
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., :3][opaque] = rgb[opaque].astype(np.uint8)
    out[..., 3][opaque] = 255
    out[..., 3][core] = 102
    out[..., 3][fringe] = 51
    return Image.fromarray(out, "RGBA")


def process_box(svg_text, w, h, shadow_off, tmpdir=None, scale=10):
    """Variante laut Brief: erst herunterrechnen, dann quantisieren (verwischt feine Linien)."""
    hi = render_svg(svg_text, w, h, scale, tmpdir)
    rgb, al = downscale(hi, w, h)
    q, op = quantize(rgb, al)
    q, op = add_outline(q, op)
    return compose(q, op, shadow_off)


def upscale(img, f=4):
    return img.resize((img.width * f, img.height * f), Image.NEAREST)


def on_space(img, pad=0):
    bg = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad), hex2rgb(SPACE) + (255,))
    bg.alpha_composite(img, (pad, pad))
    return bg.convert("RGB")


def count_colors(img):
    a = np.asarray(img)
    m = a[..., 3] == 255
    return len({tuple(p) for p in a[m][:, :3]})


def downscale_mode(hi, w, h):
    """Alternative: erst auf Palette quantisieren, dann je Block die häufigste Farbe."""
    a = np.asarray(hi, dtype=np.float64)
    s = a.shape[0] // h
    rgb = a[..., :3]
    lab = _lab(rgb.reshape(-1, 3))
    idx = np.empty(lab.shape[0], dtype=np.int64)
    for i in range(0, lab.shape[0], 200000):
        d = ((lab[i:i + 200000, None, :] - PAL_LAB[None]) ** 2).sum(-1)
        idx[i:i + 200000] = d.argmin(-1)
    idx = idx.reshape(h, s, w, s).transpose(0, 2, 1, 3).reshape(h, w, s * s)
    al = a[..., 3].reshape(h, s, w, s).transpose(0, 2, 1, 3).reshape(h, w, s * s)
    vis = al >= 127.5
    out = np.zeros((h, w, 3))
    for y in range(h):
        for x in range(w):
            v = idx[y, x][vis[y, x]]
            if len(v):
                out[y, x] = PAL[np.bincount(v).argmax()]
    return out, vis.mean(-1) >= 0.5


def process(svg_text, w, h, shadow_off, tmpdir=None, scale=10):
    """Standard: in hoher Auflösung quantisieren, dann je Block die häufigste Palettenfarbe."""
    hi = render_svg(svg_text, w, h, scale, tmpdir)
    q, op = downscale_mode(hi, w, h)
    q, op = add_outline(q, op)
    return compose(q, op, shadow_off)
