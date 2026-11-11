"""Shared helpers for the Taiga feature screenshots.

Every capture script writes into <app>/docs/features/ (a new folder; nothing
existing is overwritten) and records each image in <app>/docs/features/manifest.json
with its provenance, so the READMEs and VERIFICATION.md can say exactly how each
image was produced:

  provenance = "live"   the app's own shipped front-end (standalone HTML build), driven in Chromium
  provenance = "bench"  a test bench: the app's real stylesheets/scripts/R UI code, with a stand-in for
                        the R/Shiny server (no R runtime was available), see tools/bench/README.md
"""
from __future__ import annotations

import sys as _sys
_sys.dont_write_bytecode = True          # never write __pycache__ into the projects whose modules are imported

import datetime
import json
import os
from pathlib import Path

from PIL import Image

WS = Path(__file__).resolve().parents[3]
DS = WS / "taiga-design-system"
VIEW = {"width": 1440, "height": 900}
DPR = 2
SEED_JS = ("Math.random = (function(){let a=20260311;return function(){a|=0;a=a+0x6D2B79F5|0;"
           "let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};})();")
# hide scrollbars in stills (marketing images should not show OS chrome)
NO_SCROLLBARS = "::-webkit-scrollbar{width:0!important;height:0!important;display:none!important} html{scrollbar-width:none!important}"


def out_dir(app: str) -> Path:
    d = WS / app / "docs" / "features"
    d.mkdir(parents=True, exist_ok=True)
    return d


class Manifest:
    def __init__(self, app: str, framework: str):
        self.app, self.framework = app, framework
        self.dir = out_dir(app)
        self.path = self.dir / "manifest.json"
        self.items = {}
        if self.path.exists():
            try:
                self.items = {i["file"]: i for i in json.load(open(self.path))["shots"]}
            except Exception:  # noqa: BLE001
                self.items = {}

    def add(self, png: Path, name: str, title: str, caption: str, provenance: str, source: str, theme: str = "light",
            quality: int = 90):
        """convert the captured PNG to a web-friendly JPEG (4:4:4, no chroma blur on text) and record it"""
        im = Image.open(png).convert("RGB")
        dst = self.dir / f"{name}.jpg"
        im.save(dst, "JPEG", quality=quality, subsampling=0, optimize=True, progressive=True)
        self.items[dst.name] = {
            "file": dst.name, "title": title, "caption": caption, "provenance": provenance, "source": source,
            "theme": theme, "width": im.width, "height": im.height, "bytes": dst.stat().st_size,
            "captured": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
        print(f"   {self.app}/{dst.name}  {im.width}x{im.height}  {dst.stat().st_size // 1024} KB  [{provenance}]")
        return dst

    def save(self, order=None):
        shots = list(self.items.values())
        if order:
            rank = {n: i for i, n in enumerate(order)}
            shots.sort(key=lambda s: rank.get(s["file"].rsplit(".", 1)[0], 999))
        json.dump({"app": self.app, "framework": self.framework, "viewport": VIEW, "device_scale_factor": DPR,
                   "shots": shots}, open(self.path, "w"), indent=1)


def new_context(browser, theme="light", **kw):
    ctx = browser.new_context(viewport=VIEW, device_scale_factor=DPR, color_scheme=theme, accept_downloads=True,
                              reduced_motion="no-preference", **kw)
    ctx.add_init_script(SEED_JS)
    ctx.set_default_timeout(240000)      # 2x stills of blur-heavy pages are slow in headless Chromium without a GPU
    return ctx


def still_css(page, extra=""):
    page.add_style_tag(content=NO_SCROLLBARS + "html{scroll-behavior:auto!important}" + extra)


class ErrorLog:
    """collect page errors and console errors; the capture scripts fail loudly if a shot had errors"""
    def __init__(self, page, label):
        self.label, self.errors = label, []
        page.on("pageerror", lambda e: self.errors.append("pageerror: " + str(e)))
        page.on("console", lambda m: self.errors.append("console: " + m.text) if m.type == "error" else None)

    def report(self, allow=()):
        bad = [e for e in self.errors if not any(a in e for a in allow)]
        if bad:
            print(f"   !! {self.label}: {len(bad)} page error(s):")
            for e in bad[:8]:
                print("      ", e[:220])
        return bad
