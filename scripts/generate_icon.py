#!/usr/bin/env python3
"""Generate the AgentDock macOS app icon set.

Design (matches the app's dark theme tokens in lib/theme/app_colors.dart):
  - macOS squircle, gray-950 -> gray-900 vertical gradient, gray-800 rim
  - center: glowing accent-blue terminal prompt (the CLI core / orchestrator)
  - four colored agent nodes on an orbit, wired to the core with glowing
    links — the multi-agent orchestration network ("agents docked to a hub")
  - an AI sparkle ✦ on the empty diagonal

Usage:  python3 scripts/generate_icon.py
Writes app_icon_{16,32,64,128,256,512,1024}.png into
macos/Runner/Assets.xcassets/AppIcon.appiconset/.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

# --- Design tokens (AppColors) ---
BG_950 = (3, 7, 18)        # gray-950
BG_900 = (17, 24, 39)      # gray-900
BORDER_800 = (31, 41, 55)  # gray-800
ACCENT = (96, 165, 250)    # blue-400 — primary accent
ACCENT_LIGHT = (147, 197, 253)  # blue-300
SPARK = (219, 234, 254)    # blue-100 — AI sparkle

# Agent nodes: N / E / S / W on the orbit (emerald, amber, purple, blue).
AGENT_NODES = [
    (270, (52, 211, 153)),   # top    — emerald-400
    (0,   (251, 191, 36)),   # right  — amber-400
    (90,  (192, 132, 252)),  # bottom — purple-400
    (180, (96, 165, 250)),   # left   — blue-400
]

S = 4096                 # supersampled canvas (4x of 1024)
MARGIN = int(S * 100 / 1024)   # Apple icon grid margin
RADIUS = int(S * 185 / 1024)   # squircle-ish corner radius


def rounded_mask(size: int, box: tuple, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def vertical_gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        grad.putpixel((0, y), tuple(
            round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return grad.resize((size, size))


def glow_layer(layer: Image.Image, blur: int, times: int = 1) -> Image.Image:
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    halo = layer.filter(ImageFilter.GaussianBlur(blur))
    for _ in range(times):
        out.alpha_composite(halo)
    return out


def sparkle(draw: ImageDraw.ImageDraw, cx: int, cy: int, r: int,
            color: tuple) -> None:
    """Four-point AI star (concave diamond)."""
    waist = r * 0.22
    pts = []
    for i in range(4):
        a = math.radians(90 * i - 90)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        b = math.radians(90 * i - 45)
        pts.append((cx + waist * math.cos(b), cy + waist * math.sin(b)))
    draw.polygon(pts, fill=color)


def main() -> None:
    box = (MARGIN, MARGIN, S - MARGIN, S - MARGIN)
    icon = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    # --- Plate: gradient squircle with a subtle rim ---
    plate = vertical_gradient(S, BG_900, BG_950).convert("RGBA")
    icon.paste(plate, (0, 0), rounded_mask(S, box, RADIUS))
    ImageDraw.Draw(icon).rounded_rectangle(
        box, radius=RADIUS, outline=BORDER_800 + (255,),
        width=int(S * 0.004))

    u = (S - 2 * MARGIN) / 1024  # design unit inside the plate
    cx0 = cy0 = S // 2           # canvas center
    ORBIT = int(300 * u)         # agent orbit radius
    NODE_R = int(52 * u)         # agent node radius
    CORE_R = int(150 * u)        # where links start (edge of the core)

    # --- Faint orbit ring (the "dock" the agents sit on) ---
    ring = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(ring).ellipse(
        (cx0 - ORBIT, cy0 - ORBIT, cx0 + ORBIT, cy0 + ORBIT),
        outline=ACCENT + (46,), width=int(7 * u))
    icon.alpha_composite(ring)

    # --- Links: core -> each agent node (each in the agent's color) ---
    links = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(links)
    for angle, color in AGENT_NODES:
        a = math.radians(angle)
        x0 = cx0 + CORE_R * math.cos(a)
        y0 = cy0 + CORE_R * math.sin(a)
        x1 = cx0 + (ORBIT - NODE_R) * math.cos(a)
        y1 = cy0 + (ORBIT - NODE_R) * math.sin(a)
        ld.line([(x0, y0), (x1, y1)], fill=color + (150,),
                width=int(15 * u))
        # data pulse riding the link
        px = cx0 + (CORE_R + (ORBIT - NODE_R - CORE_R) * 0.55) * math.cos(a)
        py = cy0 + (CORE_R + (ORBIT - NODE_R - CORE_R) * 0.55) * math.sin(a)
        pr = int(14 * u)
        ld.ellipse((px - pr, py - pr, px + pr, py + pr),
                   fill=color + (255,))
    icon.alpha_composite(glow_layer(links, int(14 * u)))
    icon.alpha_composite(links)

    # --- Agent nodes on the orbit ---
    for angle, color in AGENT_NODES:
        a = math.radians(angle)
        nx = cx0 + ORBIT * math.cos(a)
        ny = cy0 + ORBIT * math.sin(a)
        node = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        nd = ImageDraw.Draw(node)
        nd.ellipse((nx - NODE_R, ny - NODE_R, nx + NODE_R, ny + NODE_R),
                   fill=color + (255,))
        icon.alpha_composite(glow_layer(node, int(16 * u), times=2))
        icon.alpha_composite(node)

    # --- Core: glowing terminal prompt `❯ ▁` (the orchestrator CLI) ---
    glyphs = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    g = ImageDraw.Draw(glyphs)
    w = int(62 * u)  # stroke width
    pcx, pcy = cx0 - int(58 * u), cy0
    arm = int(108 * u)
    chevron = [(pcx - arm // 2, pcy - arm), (pcx + arm // 2, pcy),
               (pcx - arm // 2, pcy + arm)]
    g.line(chevron, fill=ACCENT + (255,), width=w, joint="curve")
    for x, y in chevron:  # rounded caps
        g.ellipse((x - w // 2, y - w // 2, x + w // 2, y + w // 2),
                  fill=ACCENT + (255,))
    # cursor block (slightly lighter, like the xterm cursor)
    bx, by = pcx + int(122 * u), pcy + arm - int(64 * u)
    g.rounded_rectangle(
        (bx, by, bx + int(140 * u), by + int(64 * u)),
        radius=int(16 * u), fill=ACCENT_LIGHT + (235,))
    icon.alpha_composite(glow_layer(glyphs, int(30 * u), times=2))
    icon.alpha_composite(glyphs)

    # --- AI sparkles on the empty NE diagonal ---
    sp = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sp)
    sx = cx0 + int(ORBIT * 0.78)
    sy = cy0 - int(ORBIT * 0.78)
    sparkle(sd, sx, sy, int(64 * u), SPARK + (255,))
    sparkle(sd, sx - int(86 * u), sy - int(70 * u), int(26 * u),
            ACCENT_LIGHT + (220,))
    icon.alpha_composite(glow_layer(sp, int(18 * u)))
    icon.alpha_composite(sp)

    # --- Export all required sizes ---
    out_dir = (Path(__file__).resolve().parent.parent
               / "macos/Runner/Assets.xcassets/AppIcon.appiconset")
    base = icon.resize((1024, 1024), Image.LANCZOS)
    for size in (16, 32, 64, 128, 256, 512, 1024):
        img = base if size == 1024 else base.resize((size, size),
                                                    Image.LANCZOS)
        img.save(out_dir / f"app_icon_{size}.png")
        print(f"wrote app_icon_{size}.png")


if __name__ == "__main__":
    main()
