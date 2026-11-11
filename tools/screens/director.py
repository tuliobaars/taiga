"""DirectoR feature screenshots, from the test bench (see tools/bench/README.md).

The page is DirectoR's real UI: app_ui() and the srv_* renderUI outputs run in webR from DirectoR's
unmodified R files, styled by its own director.css and driven by its own director.js (state changes
are made by calling director.js's own message handlers). The films in it are real DirectoR engine
projects (python -m director scout/plan/capture/timeline on QuantSkill's and lumenJourney's
standalone HTML builds), so scout screens, storyboards, footage and the live preview are genuine.

    bash taiga-design-system/tools/bench/build_director.sh      # once: engine projects + webR render + site
    python3 taiga-design-system/tools/screens/director.py
"""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright

sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bench"))
import common as C  # noqa: E402
from sites import SITES, Server  # noqa: E402

TMP = Path(tempfile.mkdtemp(prefix="taiga-dr-"))
M = C.Manifest("DirectoR", "lumen")
SRC = "bench: R/ui.R + R/server_*.R renderers (webR, shim.R) + inst/app/www/director.{css,js}; films from the DirectoR engine"
ORDER = ["01-library", "02-library-films", "03-source-scout", "04-story", "05-shots", "06-sound", "07-look", "08-autopilot", "09-export"]
DONE = ["source", "story", "shots"]


def open_state(b, srv, state, page, title=None, done=DONE):
    ctx = C.new_context(b, "dark")
    pg = ctx.new_page()
    log = C.ErrorLog(pg, "DirectoR " + page)
    pg.goto(srv.url + "index.html"); pg.wait_for_timeout(900)
    pg.evaluate("(s) => bench.load('outputs/' + s)", state); pg.wait_for_timeout(700)
    pg.evaluate("""([s, p, t, done]) => { bench.bindInputs(); bench.tab('pages', p);
        bench.send('dr-nav', {page: p, done: s === 'library' ? [] : done, locked: s === 'library'});
        if (t) bench.send('dr-set', {id: 'proj_name', value: t}); }""", [state, page, title, done])
    pg.wait_for_timeout(2200)
    return ctx, pg, log


def shot(pg, key, title, caption):
    p = TMP / f"{key}.png"; pg.screenshot(path=str(p))
    M.add(p, key, title, caption, "bench", SRC, "dark")


def main():
    srv = Server(SITES / "director")
    with sync_playwright() as p:
        b = p.chromium.launch()
        ctx, pg, log = open_state(b, srv, "library", "lib")
        shot(pg, "01-library", "Library", "Paste a link, a Git repository or a zip; pick a template and let autopilot direct the film.")
        pg.evaluate("() => { const p = document.querySelector('.dr-page'); const h = document.querySelector('.lib-head'); p.scrollTop = h.offsetTop - 330; }")
        pg.wait_for_timeout(1200)
        shot(pg, "02-library-films", "Your films", "Each film is a project folder; the cards show what the scout saw.")
        log.report(); ctx.close()

        for page, key, title, cap in [
            ("source", "03-source-scout", "Source & scout", "The scout launched the app, explored its tabs and learned its name, colours and screens."),
            ("story", "04-story", "Story", "Storyboard written from the README and the screens, with the live preview playing the real footage."),
            ("shots", "05-shots", "Shots", "Footage recorded frame by frame with a virtual clock: each shot is an editable recipe of actions."),
            ("sound", "06-sound", "Sound", "Voice providers (with what to install), seven music moods, and the voice-over lines."),
            ("look", "07-look", "Look", "Format, theme, background and motion; every change updates the preview."),
            ("export", "09-export", "Export", "Draft or Final 1080p60, extra aspect ratios, and sibling cuts from the same footage."),
        ]:
            ctx, pg, log = open_state(b, srv, "quantskill", page, "QuantSkill")
            if page == "story":
                pg.evaluate("() => { const p = document.querySelector('.dr-page'); p.scrollTop = 0; }")
                pg.wait_for_timeout(2500)      # the preview iframe loads its first frame
            shot(pg, key, title, cap)
            log.report(); ctx.close()

        ctx, pg, log = open_state(b, srv, "library", "lib")
        pg.evaluate("""() => bench.send('dr-job', {job: 'auto', phase: 'capture', state: 'running', progress: 0.58,
            message: 'Recording\\u2026 3/4 shots done', elapsed: 151, eta: 96, started: 1})""")
        pg.wait_for_timeout(1500)
        shot(pg, "08-autopilot", "Autopilot", "Direct it for me: scout, script, voice, record, score and cut, with live progress.")
        log.report(); ctx.close()
        b.close()
    srv.close()
    M.save(ORDER)


if __name__ == "__main__":
    main()
