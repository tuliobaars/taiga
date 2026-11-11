"""Assemble bench sites (static folders served over HTTP) from the webR-rendered markup.

A site = the app's real markup (R UI code run in webR under shim.R) + Bootstrap 5.3 (npm) with the
app's bslib theme values as CSS variables + bench.css (approximations of shiny/bslib CSS) + the
app's own stylesheets and scripts, loaded last, as in the app.
"""
from __future__ import annotations

import sys as _sys
_sys.dont_write_bytecode = True          # never write __pycache__ into the projects whose modules are imported

import base64
import functools
import http.server
import os
import shutil
import socketserver
import threading
from pathlib import Path

BENCH = Path(__file__).resolve().parent
WS = BENCH.parents[2]
NM = BENCH / "node_modules"
OUT = Path("/tmp/taiga-bench")
SITES = OUT / "sites"


def vendor(site: Path):
    v = site / "vendor"; v.mkdir(parents=True, exist_ok=True)
    for src, dst in [("bootstrap/dist/css/bootstrap.min.css", "bootstrap.min.css"), ("bootstrap/dist/js/bootstrap.bundle.min.js", "bootstrap.bundle.min.js"),
                     ("jquery/dist/jquery.min.js", "jquery.min.js"), ("ion-rangeslider/css/ion.rangeSlider.min.css", "ion.rangeSlider.min.css"),
                     ("ion-rangeslider/js/ion.rangeSlider.min.js", "ion.rangeSlider.min.js")]:
        shutil.copy(NM / src, v / dst)
    fa = v / "fontawesome"; 
    if not fa.exists():
        shutil.copytree(NM / "@fortawesome/fontawesome-free/css", fa / "css"); shutil.copytree(NM / "@fortawesome/fontawesome-free/webfonts", fa / "webfonts")
    shutil.copy(BENCH / "assets/bench.css", v / "bench.css"); shutil.copy(BENCH / "assets/bench.js", v / "bench.js")


def theme_css(bg, fg, primary, font=None, dark=True, extra=""):
    def rgb(h):
        h = h.lstrip("#"); return ", ".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))
    return (":root, [data-bs-theme] {--bs-body-bg:%s;--bs-body-bg-rgb:%s;--bs-body-color:%s;--bs-body-color-rgb:%s;--bs-emphasis-color:%s;"
            "--bs-emphasis-color-rgb:%s;--bs-primary:%s;--bs-primary-rgb:%s;--bs-link-color:%s;--bs-link-color-rgb:%s;%s%s}"
            ".btn-primary{--bs-btn-bg:%s;--bs-btn-border-color:%s;--bs-btn-hover-bg:%s;--bs-btn-hover-border-color:%s;--bs-btn-active-bg:%s}"
            ".form-check-input:checked{background-color:%s;border-color:%s}"
            % (bg, rgb(bg), fg, rgb(fg), fg, rgb(fg), primary, rgb(primary), primary, rgb(primary),
               ("--bs-body-font-family:%s;" % font) if font else "", extra, primary, primary, primary, primary, primary, primary, primary))


def hoist_head(html):
    """htmltools moves tags$head() children into the document <head>; do the same for the webR markup"""
    import re
    heads = re.findall(r"<head>(.*?)</head>", html, flags=re.S)
    return re.sub(r"<head>.*?</head>", "", html, flags=re.S), "\n".join(heads)


def page(title, body, head_css=(), head_js=(), theme="", html_attrs='data-bs-theme="dark"', body_class="", pre_head="", post_head=""):
    css = "\n".join('<link rel="stylesheet" href="%s">' % c for c in head_css)
    js = "\n".join('<script src="%s"></script>' % j for j in head_js)
    return f"""<!DOCTYPE html>
<html lang="en" {html_attrs}>
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>{title}</title>
{pre_head}
<link rel="stylesheet" href="vendor/bootstrap.min.css">
<link rel="stylesheet" href="vendor/ion.rangeSlider.min.css">
<link rel="stylesheet" href="vendor/fontawesome/css/all.min.css">
<link rel="stylesheet" href="vendor/bench.css">
<style id="bench-theme">{theme}</style>
<script src="vendor/jquery.min.js"></script>
<script src="vendor/ion.rangeSlider.min.js"></script>
<script src="vendor/bench.js"></script>
<script src="vendor/bootstrap.bundle.min.js"></script>
{css}
{js}
{post_head}
</head>
<body class="{body_class}">
{body}
</body>
</html>
"""


def write_indexes(root: Path):
    """outputs/<state>/index.json: the outputs that exist for that state (bench.load reads it)"""
    import json
    for d in [p for p in root.iterdir() if p.is_dir()]:
        json.dump(sorted(f.stem for f in d.glob("*.html")), open(d / "index.json", "w"))


def inter_font(dst: Path):
    b64 = (WS / "DirectoR/inst/engine/stage/inter.woff2.b64").read_text()
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(base64.b64decode("".join(b64.split())))


def build_director():
    site = SITES / "director"
    if site.exists(): shutil.rmtree(site)
    site.mkdir(parents=True)
    vendor(site)
    www = site / "dr-www"; www.mkdir()
    for f in ("director.css", "director.js"):
        shutil.copy(WS / "DirectoR/inst/app/www" / f, www / f)
    inter_font(site / "dr-font" / "inter.woff2")
    os.symlink("/tmp/taiga-dr/home/projects", site / "drp")
    # bundled music previews (drm/w/demos/music_<mood>.mp3): not in the upload, so made with the engine's own
    # `python -m director demo` and transcoded, as the app's www would ship them
    import glob, subprocess
    demos = site / "drm" / "w" / "demos"; demos.mkdir(parents=True)
    # DirectoR's media route (R/media.R dr_media_roots()): drm/p = projects, drm/c = generated previews
    os.symlink("/tmp/taiga-dr/home/projects", site / "drm" / "p")
    os.makedirs("/tmp/taiga-dr/home/cache/demos", exist_ok=True); os.symlink("/tmp/taiga-dr/home/cache/demos", site / "drm" / "c")
    for wav in glob.glob("/tmp/taiga-demos/music_*.wav"):
        mood = os.path.basename(wav).split("_")[1]
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libmp3lame", "-q:a", "4", str(demos / f"music_{mood}.mp3")], check=True)
    shutil.copytree(OUT / "director", site / "outputs")
    write_indexes(site / "outputs")
    ui, app_head = hoist_head((OUT / "director" / "ui.html").read_text())
    # app_ui()'s <head> content (tags$head) and body: the bench page keeps the app's own head tags
    theme = theme_css("#07070a", "#f4f4f6", "#a855f7", font="Inter, -apple-system, system-ui, sans-serif",
                      extra="--bs-border-color:rgba(255,255,255,.12);--bs-secondary-bg:#16161d;--bs-tertiary-bg:#101016;")
    (site / "index.html").write_text(page("DirectoR", ui, theme=theme, post_head=app_head))
    return site


class Server:
    """serve a site folder on a free local port (symlinks followed)"""
    def __init__(self, root: Path):
        class Quiet(http.server.SimpleHTTPRequestHandler):
            def log_message(self, *a, **k): pass
        handler = functools.partial(Quiet, directory=str(root))
        self.httpd = socketserver.ThreadingTCPServer(("127.0.0.1", 0), handler)
        self.httpd.daemon_threads = True
        self.port = self.httpd.server_address[1]
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    @property
    def url(self): return "http://127.0.0.1:%d/" % self.port

    def close(self): self.httpd.shutdown()




def build_neue(app):
    """teal_neue / BlockR: the app's header, module nav, footer and pages (webR) + its inst/www (as its htmlDependency)"""
    site = SITES / app
    if site.exists(): shutil.rmtree(site)
    site.mkdir(parents=True)
    vendor(site)
    shutil.copytree(WS / app / "inst/www", site / "www")
    src = OUT / app
    body, app_head = hoist_head((src / "body.html").read_text())
    head_script = (src / "head_script.html").read_text()
    if app == "teal_neue":
        css = ["www/teal_neue.css", "www/tlg_catalog.css"]; js = ["www/tlg_catalog.js"]; deferred = ["www/teal_neue.js"]
        title = "teal_neue \u00b7 Clinical Trial Analysis"
    else:
        css = ["www/blockr.css", "www/tlg_catalog.css", "www/blockr_canvas.css"]; js = ["www/tlg_catalog.js", "www/blockr_canvas.js", "www/blockr_tutorial.js"]
        deferred = ["www/blockr.js"]; title = "BlockR \u00b7 Clinical analysis, block by block"
    for extra in ("plots", "outputs", "messages", "previews"):
        if (src / extra).exists(): shutil.copytree(src / extra, site / extra)
    if (site / "outputs").exists(): write_indexes(site / "outputs")
    post = app_head + "\n" + "\n".join('<script src="%s" defer></script>' % j for j in deferred)
    html = page(title, body, head_css=css, head_js=js, theme="", html_attrs='lang="en"', pre_head=head_script, post_head=post,
                body_class="bench-teal")
    (site / "index.html").write_text(html)
    return site


def build_teal_neue(): return build_neue("teal_neue")


def build_blockr(): return build_neue("BlockR")


def build_rockshiny():
    """RockShiny: app.R's ui() (webR) + its three htmlDependencies (app chrome, highway, dropzone) + chart fixtures"""
    import json
    site = SITES / "rockshiny"
    if site.exists(): shutil.rmtree(site)
    site.mkdir(parents=True)
    vendor(site)
    src = OUT / "rockshiny"
    deps = json.loads((src / "ui" / "deps.json").read_text())
    css, js = [], []
    for d in deps:
        name = d["name"]; folder = WS / "RockShiny" / d["src"][len("/app/"):]
        shutil.copytree(folder, site / "deps" / name)
        for c in ([d["stylesheet"]] if isinstance(d["stylesheet"], str) else d["stylesheet"] or []): css.append(f"deps/{name}/{c}")
        for j in ([d["script"]] if isinstance(d["script"], str) else d["script"] or []): js.append(f"deps/{name}/{j}")
    shutil.copytree(src / "charts", site / "charts")
    shutil.copytree(src / "audio", site / "audio"); shutil.copy(src / "songs.json", site / "songs.json")
    inter_font(site / "fonts" / "inter.woff2")
    body, app_head = hoist_head((src / "ui" / "ui.html").read_text())
    theme = theme_css("#0b0d13", "#e8eaf1", "#f5a524", font="Inter, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif",
                      extra="--bs-body-font-size:.9rem;--bs-border-radius:.55rem;--bs-secondary-color:rgba(232,234,241,.6);"
                            "--bs-border-color:rgba(255,255,255,.10);--bs-secondary-bg:#141824;--bs-tertiary-bg:#10131c;")
    theme += ("@font-face{font-family:'Inter';src:url(fonts/inter.woff2) format('woff2');font-weight:100 900}"
              ".form-control,.form-select{background-color:#141824;border-color:rgba(255,255,255,.10);color:#e8eaf1}"
              ".accordion{--bs-accordion-bg:transparent;--bs-accordion-color:#e8eaf1;--bs-accordion-btn-color:#e8eaf1;--bs-accordion-active-color:#f5a524}")
    body_class = (src / "ui" / "body_class.txt").read_text().strip()
    (site / "index.html").write_text(page("RockShiny", body, head_css=css, head_js=js, theme=theme, post_head=app_head, body_class=body_class))
    return site


if __name__ == "__main__":
    import sys
    for name in sys.argv[1:] or ["director"]:
        print(globals()["build_" + name]())
