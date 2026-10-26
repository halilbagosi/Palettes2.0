"""Build layered App Store screenshot assets for Pixelmator Pro.

Per screen, every layer shares one full-size canvas so they stack at 0,0:
  NN-1-background.svg  gradient glow + headline/subhead (editable text)
  NN-2-screen.png      the capture, scaled and corner-rounded, in position
  NN-3-frame.svg       device bezel + Dynamic Island, screen area transparent
  NN-preview.svg       all three combined (screen embedded) for reference
"""
import base64, io, sys
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent

DEVICES = {
    "iphone": dict(
        canvas=(1320, 2868), screen_w=980, screen_top=640, radius=134, bezel=24,
        # Width, height and offset from the screen top in points (measured on an
        # iPhone 18 Pro capture); scaled to the capture's @3x point width.
        island_pt=(94.7, 36.7, 14),
        title_y=250, title_size=112, sub_size=50, line_gap=128,
    ),
    "ipad": dict(
        canvas=(2064, 2752), screen_w=1440, screen_top=540, radius=52, bezel=40,
        island_pt=None,
        title_y=230, title_size=120, sub_size=54, line_gap=138,
    ),
}

SCREENS = [
    ("01-library", ["Your palettes,", "beautifully kept"], "Favorites, filters and one-tap hex copy",
     ["#F2A65A", "#2F6690", "#A3B18A"]),
    ("02-generate-mixing", ["Describe a vibe.", "Watch it mix."], "On-device Apple Intelligence builds the palette",
     ["#1494B9", "#BE6438", "#00C3F5"]),
    ("03-generate-result", ["Named, tuned", "and ready to save"], "Refine it with a sentence: “more muted”",
     ["#BE6438", "#00C3F5", "#77391A"]),
    ("04-palette-roles", ["Tag colors with", "real UI roles"], "Primary, Accent, Background, Text and your own",
     ["#F2A65A", "#C8553D", "#5B3758"]),
    ("05-harmony", ["Built on real", "color theory"], "Complementary, triadic, analogous and more",
     ["#C8553D", "#00A3C4", "#7B8CFF"]),
    ("06-export", ["Export straight", "into your code"], "CSS, SCSS, Tailwind, SwiftUI, JSON and SVG",
     ["#C8553D", "#F2A65A", "#2E2A4F"]),
    ("07-colors", ["Every color", "in one place"], "Sorted around the color wheel",
     ["#EE6C4D", "#FF8C42", "#E9D8A6"]),
    ("08-search", ["Find any color", "in a second"], "Search by name, hex, hue or role",
     ["#F2A65A", "#9AD1D4", "#5B3758"]),
]


# Background and caption styling per appearance. Light keeps a dark bezel,
# like the real hardware.
THEMES = {
    "dark": dict(base=("#121016", "#050506"), glow=(0.55, 0.45, 0.40), ink="#FFFFFF", sub_opacity=0.72,
                 rim=("#5A5862", "#2A292F", "#4A4852")),
    "light": dict(base=("#FBFAF8", "#EFECE8"), glow=(0.42, 0.34, 0.30), ink="#1C1C1E", sub_opacity=0.62,
                  rim=("#C9C7CE", "#7A7880", "#B4B2BA")),
}

# Per-device glow overrides where that device's capture uses other colors.
GLOWS = {
    ("ipad", "dark", "02-generate-mixing"): ["#00976D", "#0E9A9A", "#5CB100"],
    ("ipad", "light", "02-generate-mixing"): ["#5A9B47", "#FF3FA4", "#8E80D0"],
    ("iphone", "light", "02-generate-mixing"): ["#BE6438", "#FF4F6D", "#E79C78"],
    ("iphone", "light", "03-generate-result"): ["#BE6438", "#FF4F6D", "#AE782A"],
    ("iphone", "dark", "02-generate-mixing"): ["#587DCE", "#C16964", "#00C82B"],
    ("iphone", "dark", "03-generate-result"): ["#BE6438", "#009A9A", "#4499FF"],
}


def geometry(d, shot_size):
    cw, ch = d["canvas"]
    sw = d["screen_w"]
    sh = round(sw * shot_size[1] / shot_size[0])
    sx = (cw - sw) // 2
    sy = d["screen_top"]
    return cw, ch, sx, sy, sw, sh


def island_px(d, shot_size):
    if not d["island_pt"]:
        return None
    k = d["screen_w"] / (shot_size[0] / 3)
    return tuple(round(v * k, 1) for v in d["island_pt"])


def background_svg(d, t, geo, title, sub, glows):
    cw, ch, sx, sy, sw, sh = geo
    g1, g2, g3 = glows
    o1, o2, o3 = t["glow"]
    lines = "".join(
        f'<tspan x="{cw/2}" dy="{0 if i == 0 else d["line_gap"]}">{t}</tspan>'
        for i, t in enumerate(title)
    )
    sub_y = d["title_y"] + d["line_gap"] * (len(title) - 1) + d["sub_size"] * 1.9
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{cw}" height="{ch}" viewBox="0 0 {cw} {ch}">
  <defs>
    <linearGradient id="base" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{t["base"][0]}"/>
      <stop offset="1" stop-color="{t["base"][1]}"/>
    </linearGradient>
    <radialGradient id="glow1" cx="0.15" cy="0.30" r="0.65">
      <stop offset="0" stop-color="{g1}" stop-opacity="{o1}"/>
      <stop offset="1" stop-color="{g1}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glow2" cx="0.95" cy="0.55" r="0.60">
      <stop offset="0" stop-color="{g2}" stop-opacity="{o2}"/>
      <stop offset="1" stop-color="{g2}" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glow3" cx="0.40" cy="1.0" r="0.60">
      <stop offset="0" stop-color="{g3}" stop-opacity="{o3}"/>
      <stop offset="1" stop-color="{g3}" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <g id="background">
    <rect width="{cw}" height="{ch}" fill="url(#base)"/>
    <rect width="{cw}" height="{ch}" fill="url(#glow1)"/>
    <rect width="{cw}" height="{ch}" fill="url(#glow2)"/>
    <rect width="{cw}" height="{ch}" fill="url(#glow3)"/>
  </g>
  <g id="caption" text-anchor="middle" fill="{t["ink"]}">
    <text id="headline" y="{d["title_y"]}" font-family="SF Pro Display, -apple-system, Helvetica Neue, sans-serif" font-weight="700" font-size="{d["title_size"]}" letter-spacing="-1.5">{lines}</text>
    <text id="subhead" x="{cw/2}" y="{sub_y:.0f}" font-family="SF Pro Text, -apple-system, Helvetica Neue, sans-serif" font-weight="500" font-size="{d["sub_size"]}" fill-opacity="{t["sub_opacity"]}">{sub.replace("&", "&amp;")}</text>
  </g>
</svg>
'''


def frame_svg(d, t, geo, island_dims):
    cw, ch, sx, sy, sw, sh = geo
    b, r = d["bezel"], d["radius"]
    ox, oy, ow, oh, orr = sx - b, sy - b, sw + 2 * b, sh + 2 * b, r + b
    island = ""
    if island_dims:
        iw, ih, io_ = island_dims
        island = f'<rect id="dynamic-island" x="{cw/2 - iw/2}" y="{sy + io_}" width="{iw}" height="{ih}" rx="{ih/2}" fill="#000000"/>'
    # Even-odd path: outer bezel minus the screen, so the screen layer shows through.
    def rr(x, y, w, h, rad):
        return (f"M{x+rad},{y} H{x+w-rad} A{rad},{rad} 0 0 1 {x+w},{y+rad} V{y+h-rad} "
                f"A{rad},{rad} 0 0 1 {x+w-rad},{y+h} H{x+rad} A{rad},{rad} 0 0 1 {x},{y+h-rad} "
                f"V{y+rad} A{rad},{rad} 0 0 1 {x+rad},{y} Z")
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{cw}" height="{ch}" viewBox="0 0 {cw} {ch}">
  <defs>
    <linearGradient id="rim" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{t["rim"][0]}"/>
      <stop offset="0.5" stop-color="{t["rim"][1]}"/>
      <stop offset="1" stop-color="{t["rim"][2]}"/>
    </linearGradient>
  </defs>
  <g id="device-frame">
    <path id="bezel" fill-rule="evenodd" fill="#0B0B0D" d="{rr(ox, oy, ow, oh, orr)} {rr(sx, sy, sw, sh, r)}"/>
    <path id="rim" fill="none" stroke="url(#rim)" stroke-width="5" d="{rr(ox + 2.5, oy + 2.5, ow - 5, oh - 5, orr - 2.5)}"/>
    {island}
  </g>
</svg>
'''


def screen_png(d, geo, shot):
    cw, ch, sx, sy, sw, sh = geo
    scaled = shot.convert("RGB").resize((sw, sh), Image.LANCZOS)
    # Supersampled mask for smooth corners.
    s = 4
    mask = Image.new("L", (sw * s, sh * s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw * s - 1, sh * s - 1), d["radius"] * s, fill=255)
    mask = mask.resize((sw, sh), Image.LANCZOS)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.paste(scaled, (sx, sy), mask)
    return canvas


def preview_svg(bg, frame, screen_img):
    buf = io.BytesIO()
    screen_img.save(buf, "PNG")
    data = base64.b64encode(buf.getvalue()).decode()
    cw, ch = screen_img.size
    inner = lambda svg: svg.split(">", 1)[1].rsplit("</svg>", 1)[0]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{cw}" height="{ch}" viewBox="0 0 {cw} {ch}">'
            f'{inner(bg)}<image width="{cw}" height="{ch}" xlink:href="data:image/png;base64,{data}"/>'
            f'{inner(frame)}</svg>')


def main(device, theme):
    d, t = DEVICES[device], THEMES[theme]
    raw = OUT / "raw" / device / theme
    dest = OUT / device / theme
    dest.mkdir(parents=True, exist_ok=True)
    for name, title, sub, glows in SCREENS:
        src = raw / f"{name}.png"
        if not src.exists():
            print("skip", src)
            continue
        shot = Image.open(src)
        glows = GLOWS.get((device, theme, name), glows)
        geo = geometry(d, shot.size)
        bg = background_svg(d, t, geo, title, sub, glows)
        fr = frame_svg(d, t, geo, island_px(d, shot.size))
        scr = screen_png(d, geo, shot)
        num = name[:2]
        (dest / f"{num}-1-background.svg").write_text(bg)
        scr.save(dest / f"{num}-2-screen.png")
        (dest / f"{num}-3-frame.svg").write_text(fr)
        (dest / f"{num}-preview.svg").write_text(preview_svg(bg, fr, scr))
        print("built", device, theme, name)


if __name__ == "__main__":
    for dev in sys.argv[1:] or ["iphone", "ipad"]:
        for theme in THEMES:
            main(dev, theme)
