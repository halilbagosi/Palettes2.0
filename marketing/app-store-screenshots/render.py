"""Render preview SVGs to PNG via QuickLook: pad to a square, then crop."""
import subprocess, sys, tempfile
from pathlib import Path
from PIL import Image
for p in map(Path, sys.argv[2:]):
    svg = p.read_text()
    w, h = (int(v) for v in svg.split('viewBox="0 0 ', 1)[1].split('"')[0].split())
    side = max(w, h)
    inner = svg.split(">", 1)[1].rsplit("</svg>", 1)[0]
    head = svg.split(">", 1)[0]
    sq = (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="{side}" height="{side}" viewBox="0 0 {side} {side}">'
          f'<g transform="translate({(side-w)/2},{(side-h)/2})">{inner}</g></svg>')
    with tempfile.TemporaryDirectory() as t:
        src = Path(t) / (p.stem + ".svg"); src.write_text(sq)
        subprocess.run(["qlmanage", "-t", "-s", str(side), "-o", t, str(src)], capture_output=True)
        im = Image.open(Path(t) / (src.name + ".png"))
        k = im.size[0] / side
        im = im.crop((round((side-w)/2*k), round((side-h)/2*k), round(((side-w)/2+w)*k), round(((side-h)/2+h)*k)))
        im = im.convert("RGB").resize((w, h), Image.LANCZOS)
        out = Path(sys.argv[1]) / (p.stem + ".png"); im.save(out); print(out, im.size)
