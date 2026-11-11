"""Record DirectoR footage for its promo, with QuantSkill's deterministic recorder (read-only import).

Uses QuantSkill/dev/video/recorder.py (Recorder: virtual clock, frame-stepped CSS animations, seeded
Math.random; Cursor: drawn cursor that drives the real mouse) against the DirectoR bench site
(tools/bench: DirectoR's real UI code and assets, real engine projects). State changes that the R server
would push (job progress, detected source chip) are sent through director.js's own message handlers.

    python3 shots.py [group ...]        # groups: library, pages, export   (default: all)
Frames: $QS_VIDEO_BUILD/shots/<shot>/f00000.jpg  (QS_VIDEO_BUILD defaults to /tmp/drvideo here)
"""
from __future__ import annotations

import sys as _sys
_sys.dont_write_bytecode = True          # never write __pycache__ into the projects whose modules are imported

import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
WS = HERE.parents[3]
os.environ.setdefault("QS_VIDEO_BUILD", "/tmp/drvideo")
BUILD = Path(os.environ["QS_VIDEO_BUILD"])
SHOTS = BUILD / "shots"
sys.path.insert(0, str(WS / "QuantSkill" / "dev" / "video"))
sys.path.insert(0, str(WS / "taiga-design-system" / "tools" / "bench"))
from recorder import Recorder, Cursor  # noqa: E402  (QuantSkill's recorder)
from sites import SITES, Server  # noqa: E402

SCALE = 1.5                      # 1440x810 viewport -> 2160x1215 frames (room for camera zooms)
OUTS = Path("/tmp/taiga-bench/director")
DETECT = (OUTS / "detect_dir.html").read_text() if (OUTS / "detect_dir.html").exists() else ""


def out(name): return str(SHOTS / name)


def open_bench(r, srv, state, page, title=None, done=("source", "story", "shots")):
    r.goto(srv.url + "index.html")
    r.idle(400)
    r.js("(s) => bench.load('outputs/' + s)", state)
    r.js("""([s, p, t, done]) => { bench.bindInputs(); bench.tab('pages', p);
        bench.send('dr-nav', {page: p, done: s === 'library' ? [] : done, locked: s === 'library'});
        if (t) bench.send('dr-set', {id: 'proj_name', value: t}); }""", [state, page, title, list(done)])
    r.idle(900)


def show_page(r, page, title="QuantSkill", done=("source", "story", "shots")):
    """switch studio page in place (the recorder's virtual clock cannot restart with a second goto)"""
    r.js("""([p, t, done]) => { bench.tab('pages', p); bench.send('dr-nav', {page: p, done: done, locked: false});
        if (t) bench.send('dr-set', {id: 'proj_name', value: t}); document.querySelector('.dr-page').scrollTop = 0; }""", [page, title, list(done)])


def scroll_page(r, to, ms):
    """smooth scroll of the studio's page container (.dr-page), frame by frame"""
    y0 = r.js("document.querySelector('.dr-page').scrollTop")
    ease = lambda t: t * t * (3 - 2 * t)
    def each(i, n):
        r.js("(y) => { document.querySelector('.dr-page').scrollTop = y; }", y0 + (to - y0) * ease((i + 1) / n))
    r.rec(ms, each)


def job(r, **st):
    r.js("(m) => bench.send('dr-job', m)", st)


def g_library():
    """Library: paste a folder, the source is detected, Create film; then the autopilot overlay"""
    srv = Server(SITES / "director")
    r = Recorder(out("lib"), width=1440, height=810, scale=SCALE, theme="dark")
    open_bench(r, srv, "library", "lib")
    r.rec(500)
    cur = Cursor(r, 1180, 640); cur.show(200)
    cur.click_on("#lib_source", 700, mark="focus")
    for ch in "~/code/quantskill":
        r.page.keyboard.type(ch); r.rec(55)
    r.js("(h) => bench.send('dr-detect', {html: h})", DETECT); r.rec(450)
    cur.click_on("#lib_create", 650, mark="create"); r.rec(300)
    cur.hide(150)
    # autopilot: the job messages the server relays from the engine's status.json (phases and texts as the engine reports them)
    r.set_out(out("auto"))
    steps = [("scout", 0.04, "Launching Static website\u2026"), ("scout", 0.09, "Exploring tab \u201cAssess\u201d\u2026"),
             ("scout", 0.14, "Exploring tab \u201cTeam\u201d\u2026"), ("plan", 0.2, "Writing the storyboard\u2026"),
             ("voice", 0.27, "Voice-over: 8 lines\u2026"), ("capture", 0.36, "Recording\u2026 1/4 shots done"),
             ("capture", 0.45, "Recording\u2026 3/4 shots done"), ("music", 0.6, "Composing the score\u2026"),
             ("render", 0.72, "Rendering\u2026 40%"), ("render", 0.86, "Rendering\u2026 80%")]
    for i, (ph, p, msg) in enumerate(steps):
        job(r, job="auto", phase=ph, state="running", progress=p, message=msg, elapsed=20 + i * 18, eta=max(8, 190 - i * 19), started=1)
        r.rec(520)
    r.rec(300)
    print("library errors:", r.errors); r.close(); srv.close()


def g_pages():
    """Source (what the scout saw), Story (live preview playing), Shots (hover plays), Sound (a mood), Look"""
    srv = Server(SITES / "director")
    r = Recorder(out("source"), width=1440, height=810, scale=SCALE, theme="dark")
    open_bench(r, srv, "quantskill", "source", "QuantSkill")
    r.rec(400)
    scroll_page(r, 520, 2200); r.rec(700)
    # story: the live preview (DirectoR's preview.js in an iframe) plays the storyboard with the real footage
    r.set_out(out("story"))
    show_page(r, "story")
    r.idle(1800)
    r.rec(300)
    cur = Cursor(r, 900, 700); cur.show(150)
    bb = r.page.locator("#story_player iframe.dr-player").bounding_box()
    cur.move((bb["x"] + 26, bb["y"] + bb["height"] - 26), 600)
    cur.click(mark="play")
    r.js("() => bench.send('dr-player', {type: 'dr:play'})")
    r.rec(3600)
    cur.hide(150)
    # shots: hovering a card plays its footage
    r.set_out(out("shots"))
    show_page(r, "shots"); r.idle(500)
    r.rec(300)
    cur = Cursor(r, 700, 650); cur.show(150)
    cur.move(".shot-card, .shot, [class*=shot] .poster", 700)
    r.mark("sweep"); r.rec(2600)          # "sweep": a marker name music.py does not treat as a click
    cur.hide(150)
    # sound: pick a mood
    r.set_out(out("sound"))
    show_page(r, "sound"); r.idle(500)
    r.rec(300)
    cur = Cursor(r, 1000, 600); cur.show(150)
    cur.click_on('#music_mood button[data-value="pulse"]', 700, mark="mood"); r.rec(1800)
    cur.hide(150)
    # look: format and background
    r.set_out(out("look"))
    show_page(r, "look"); r.idle(500)
    r.rec(300)
    cur = Cursor(r, 700, 600); cur.show(150)
    cur.click_on('#look_background button[data-value="mesh"]', 700, mark="bg"); r.rec(600)
    cur.click_on('#look_theme button[data-value="dark"]', 600, mark="theme"); r.rec(900)
    cur.hide(150)
    print("pages errors:", r.errors); r.close(); srv.close()


def g_export():
    """Export: Render film, the job dock follows the render"""
    srv = Server(SITES / "director")
    r = Recorder(out("export"), width=1440, height=810, scale=SCALE, theme="dark")
    open_bench(r, srv, "quantskill", "export", "QuantSkill")
    r.rec(300)
    cur = Cursor(r, 800, 600); cur.show(150)
    cur.click_on("#export_go", 700, mark="render"); r.rec(200)
    for i, (p, msg) in enumerate([(0.06, "Building the timeline\u2026"), (0.22, "Rendering\u2026 18%"), (0.41, "Rendering\u2026 39%"),
                                  (0.63, "Rendering\u2026 61%"), (0.84, "Rendering\u2026 82%"), (0.97, "Muxing: loudness, captions, poster\u2026")]):
        job(r, job="render", state="running", progress=p, message=msg, elapsed=4 + i * 11, eta=max(3, 66 - i * 12), started=2)
        r.rec(480)
    job(r, job="render", state="done", progress=1, message="Final film ready \u00b7 1920\u00d71080 \u00b7 60 fps", elapsed=71, started=2)
    r.mark("reveal"); r.rec(1200)         # "reveal": not a click (music.py click_times())
    cur.hide(150)
    print("export errors:", r.errors); r.close(); srv.close()


GROUPS = {"library": g_library, "pages": g_pages, "export": g_export}
GROUP_SHOTS = {"library": ["lib", "auto"], "pages": ["source", "story", "shots", "sound", "look"], "export": ["export"]}


def run(name):
    GROUPS[name](); return name


if __name__ == "__main__":
    names = sys.argv[1:] or list(GROUPS)
    SHOTS.mkdir(parents=True, exist_ok=True)
    with ProcessPoolExecutor(max_workers=min(3, len(names))) as ex:
        for n in ex.map(run, names): print("done", n, flush=True)
    json.dump({g: {s: len(list((SHOTS / s).glob("f*.jpg"))) for s in GROUP_SHOTS[g]} for g in names}, open(BUILD / "shots_done.json", "w"))
