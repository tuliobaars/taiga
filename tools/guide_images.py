#!/usr/bin/env python3
"""Build the images of the guides and the README inside the package (inst/guides/img/), so they show wherever
the package is viewed: on its own, installed, or in repositories that ignore the projects' docs/ folders.

The documents decide what is built: every reference `img/full/<key>.jpg` or `img/thumb/<key>.jpg` in
inst/guides/**/*.md and README.md is (re)built from its source; images no longer referenced are removed.
Pictures are shown as thumbnails that link to the full image (click to expand):
    [![alt](img/thumb/<key>.jpg)](img/full/<key>.jpg)

Keys and sources
  <App>-<shot>                a feature screenshot: <App>/docs/features/<shot>.jpg
  DirectoR-teaser-poster      DirectoR/media/DirectoR_teaser_30s_poster.png
  format-<name>               a format picture: /tmp/taiga-formats/<name>.png (tools/screens/formats.py)
  diagram-<name>              tools/diagrams/<name>.html, rendered in Chromium
  planned-<App>-<format>      a "planned" tile for a format that is specified but not built (tools/diagrams/planned.html)

    python3 tools/guide_images.py
"""
import sys as _sys
_sys.dont_write_bytecode = True
import base64, glob, os, re, subprocess, tempfile, urllib.parse
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent; DS = HERE.parent; WS = DS.parent
IMG = DS / "inst" / "guides" / "img"; FULL = IMG / "full"; THUMB = IMG / "thumb"
APPS = ["QuantSkill", "lumenJourney", "DirectoR", "RockShiny", "teal_neue", "BlockR"]
REF = re.compile(r"img/(?:full|thumb)/([A-Za-z0-9_.\-]+)\.jpg")
FULL_W, THUMB_W, DIAGRAM_FULL_W, DIAGRAM_THUMB_W = 1280, 640, 1600, 1000

PLANNED = {  # from DELIVERY_MODEL.md section 5.1
    ("DirectoR", "quarto"): ("dr_export_quarto(project)", "A press-kit document: the film, the script with timings, the storyboard, stills.", 1),
    ("DirectoR", "html"): ("dr_export_html(project)", "One file per film: video, captions, poster and script, or the live preview inlined.", 1),
    ("RockShiny", "quarto"): ("rs_quarto_block(song, ...)", "A highway inside a lesson document, with sections and loops as links.", 1),
    ("RockShiny", "html"): ("rs_export_html(song, arrangement, instrument)", "Chart JSON and the highway inline, with guide tones; audio only with the right to share it.", 1),
    ("teal_neue", "quarto"): ("teal_neue_export_quarto(outputs, data)", "A report: chosen TLG outputs with their runnable code, and the study overview.", 0),
    ("teal_neue", "html"): ("teal_neue_export_html(data)", "The study at a glance and a static TLG appendix, with the filters stated.", 0),
    ("BlockR", "quarto"): ("blockr_export_quarto(canvas)", "The canvas as a document: one chunk per stack, block summaries as prose, the SAS translation.", 0),
    ("BlockR", "html"): ("blockr_export_html(canvas)", "A read-only canvas with its result, for offline review.", 0),
}


def referenced():
    docs = list((DS / "inst" / "guides").rglob("*.md")) + [DS / "README.md"]
    keys = set()
    for d in docs: keys |= set(REF.findall(d.read_text(encoding="utf-8")))
    return sorted(keys)


def render(url, out, width, height=None, dpr=2):
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        b = p.chromium.launch(args=["--allow-file-access-from-files"])
        pg = b.new_page(viewport={"width": width, "height": height or 800}, device_scale_factor=dpr)
        errs = []; pg.on("pageerror", lambda e: errs.append(str(e)))
        pg.goto(url); pg.evaluate("document.fonts.ready"); pg.wait_for_timeout(400)
        pg.screenshot(path=str(out), full_page=height is None)
        b.close()
    if errs: raise SystemExit("render errors in %s: %s" % (url, errs))


def source(key, tmp):
    m = re.match(r"^(%s)-(.+)$" % "|".join(APPS), key)
    if key == "DirectoR-teaser-poster": return WS / "DirectoR" / "media" / "DirectoR_teaser_30s_poster.png", False
    if key.startswith("format-"):
        p = Path("/tmp/taiga-formats") / (key[7:] + ".png")
        if not p.exists(): subprocess.run([sys.executable, str(HERE / "screens" / "formats.py")], check=True)
        return p, False
    if key.startswith("diagram-"):
        out = tmp / (key + ".png"); render((HERE / "diagrams" / (key[8:] + ".html")).as_uri(), out, 1600); return out, True
    if key.startswith("planned-"):
        app, fmt = key[8:].rsplit("-", 1); fn, what, dark = PLANNED[(app, fmt)]
        q = urllib.parse.urlencode({"app": app, "format": fmt, "fn": fn, "what": what, "dark": dark})
        out = tmp / (key + ".png"); render((HERE / "diagrams" / "planned.html").as_uri() + "?" + q, out, 1280, 800, dpr=1); return out, False
    if m:
        p = WS / m.group(1) / "docs" / "features" / (m.group(2) + ".jpg")
        if p.exists(): return p, False
    raise SystemExit("no source for image key '%s'" % key)


def save(im, path, width, quality):
    if im.width > width: im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    im.save(path, "JPEG", quality=quality, optimize=True, progressive=True, subsampling=0 if quality >= 85 else 2)


def main():
    FULL.mkdir(parents=True, exist_ok=True); THUMB.mkdir(parents=True, exist_ok=True)
    # the diagrams use Inter (DirectoR ships it, base64)
    font = HERE / "diagrams" / "inter.woff2"
    if not font.exists(): font.write_bytes(base64.b64decode("".join((WS / "DirectoR/inst/engine/stage/inter.woff2.b64").read_text().split())))
    keys = referenced(); tmp = Path(tempfile.mkdtemp(prefix="taiga-img-"))
    for key in keys:
        src, diagram = source(key, tmp)
        im = Image.open(src).convert("RGB")
        save(im, FULL / (key + ".jpg"), DIAGRAM_FULL_W if diagram else FULL_W, 88 if diagram else 80)
        save(im, THUMB / (key + ".jpg"), DIAGRAM_THUMB_W if diagram else THUMB_W, 85 if diagram else 78)
    for d in (FULL, THUMB):
        for f in d.glob("*.jpg"):
            if f.stem not in keys: f.unlink()
    size = sum(f.stat().st_size for f in IMG.rglob("*.jpg"))
    print("%d images (full + thumb), %.1f MB in %s" % (len(keys), size / 1e6, IMG.relative_to(DS)))


if __name__ == "__main__":
    main()
