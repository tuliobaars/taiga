"""lumenJourney feature screenshots, from the real study-story front end.

Pages are assembled by the project's own tools/story-dev/build.mjs (exactly like
lumen::story_html(): inst/story/lumen-story.{js,css} + profiles + data payload) into a temp
folder, then driven in Chromium.

    python3 taiga-design-system/tools/screens/lumen_journey.py
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright

sys.path.insert(0, str(Path(__file__).parent))
import common as C  # noqa: E402

LJ = C.WS / "lumenJourney"
TMP = Path(tempfile.mkdtemp(prefix="taiga-lj-"))
M = C.Manifest("lumenJourney", "lumen")
SRC = "inst/story/ assembled by tools/story-dev/build.mjs (same as story_html())"
ORDER = ["01-hero", "02-glance", "03-journey", "04-population", "05-efficacy", "06-safety", "07-explore", "08-study-setup",
         "09-journey-4-arms", "10-light-efficacy"]


def build(name, *flags):
    out = TMP / f"{name}.html"
    subprocess.run(["node", str(LJ / "tools/story-dev/build.mjs"), str(out), *flags], check=True, cwd=str(LJ),
                   stdout=subprocess.DEVNULL)
    return out.as_uri()


def open_page(b, url, theme="dark"):
    ctx = C.new_context(b, theme)
    pg = ctx.new_page()
    log = C.ErrorLog(pg, "lumenJourney " + url.rsplit("/", 1)[-1])
    pg.goto(url); pg.wait_for_timeout(3500)
    C.still_css(pg)
    return ctx, pg, log


def to_section(pg, sel, offset=120, settle=2600):
    """scroll so the section heading (h2, past the section's top padding) sits just under the sticky nav;
    done twice because revealing a section can shift the layout above it"""
    for wait in (900, settle):
        y = pg.evaluate("""(sel) => { const e = document.querySelector(sel); const h = e.querySelector('h2') || e;
            return h.getBoundingClientRect().top + scrollY; }""", sel)
        pg.evaluate("(y) => window.scrollTo(0, y)", max(0, y - offset))
        pg.wait_for_timeout(wait)


def to_step(pg, k, settle=3000):
    """centre journey step k (0-based) in the viewport: its card and its dot chart are then fully in view"""
    for wait in (900, settle):
        y = pg.evaluate("""(k) => { const s = document.querySelectorAll('#ls-journey .ls-j-step')[k];
            return s.getBoundingClientRect().top + scrollY + s.offsetHeight / 2 - innerHeight / 2; }""", k)
        pg.evaluate("(y) => window.scrollTo(0, y)", y)
        pg.wait_for_timeout(wait)


def shot(pg, key, title, caption, theme="dark"):
    p = TMP / f"{key}.png"; pg.screenshot(path=str(p))
    M.add(p, key, title, caption, "live", SRC, theme)


def main():
    onc = build("oncology")
    car = build("cardio4", "--area=cardiology", "--source=simulated", "--patients=1500", "--arms=4")
    light = build("light", "--theme=light")
    with sync_playwright() as p:
        b = p.chromium.launch()
        ctx, pg, log = open_page(b, onc)
        pg.wait_for_timeout(1500)
        shot(pg, "01-hero", "Hero", "Cinematic dark hero: gradient study name, count-up key figures, disease-area chips.")
        to_section(pg, "#ls-glance")
        shot(pg, "02-glance", "At a glance", "Plain-language results for non-technical readers, on glass cards.")
        to_step(pg, 3)
        shot(pg, "03-journey", "Patient journey", "Scroll-driven story: every dot is a patient; here, coloured by how their tumour responded.")
        to_section(pg, "#ls-population")
        shot(pg, "04-population", "Who took part", "Baseline characteristics, age pyramid and countries.")
        to_section(pg, "#ls-efficacy")
        shot(pg, "05-efficacy", "Did it work", "Kaplan-Meier curves, hazard ratio and response, computed in the browser.")
        to_section(pg, "#ls-safety")
        shot(pg, "06-safety", "Was it safe", "Adverse events by arm and grade.")
        to_section(pg, "#ls-explore")
        shot(pg, "07-explore", "Explore", "A free explorer with global filters and subgroup drill-down.")
        pg.evaluate("window.scrollTo(0, 0)"); pg.wait_for_timeout(800)
        pg.click(".ls-setup-btn"); pg.wait_for_timeout(1800)
        shot(pg, "08-study-setup", "Study setup", "Reshape the fictitious study (disease area, patients, arms, effect) or load your own ADaM data.")
        log.report(); ctx.close()

        ctx, pg, log = open_page(b, car)
        to_step(pg, 1)
        shot(pg, "09-journey-4-arms", "Journey, four arms", "The same story rebuilt in the browser: cardiology, 1,500 patients, randomised to four arms.")
        log.report(); ctx.close()

        ctx, pg, log = open_page(b, light, theme="light")
        to_section(pg, "#ls-efficacy", offset=175)      # the paper theme sets the eyebrow further above the heading
        shot(pg, "10-light-efficacy", "Light theme", "The paper-toned light theme (warm greys, hairlines, Helvetica Neue).", theme="light")
        log.report(); ctx.close()
        b.close()
    M.save(ORDER)
    shutil.rmtree(TMP, ignore_errors=True)


if __name__ == "__main__":
    main()
