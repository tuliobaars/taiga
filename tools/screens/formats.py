"""One picture per delivery format (Shiny, Quarto, HTML) for the two projects that ship all three.

    python3 taiga-design-system/tools/screens/formats.py       -> /tmp/taiga-formats/*.png (1440 x 900)

QuantSkill
  html    inst/html/quantskill.html (the standalone build)
  quarto  quarto/quantskill.html: the Quarto render shipped in the project (quarto 1.9.38; front end v2.0.0),
          on its Method page, where the author's own Quarto markdown appears
  shiny   the Shiny front end (inst/app/www) against QuantSkill's own protocol stand-in
          (dev/simulate/cohort.py MockServer + PAGE, as its video pipeline uses for the Shiny shot)
lumenJourney
  html    the story assembled by tools/story-dev/build.mjs (as story_html(mode = "html"))
  quarto  inst/quarto/lumen-story.html: the Quarto render shipped in the project (quarto 1.9.38)
  shiny   build.mjs --mode=shiny (as story_html(mode = "shiny")), whose Study setup offers uploads and server folders
"""
from __future__ import annotations

import sys as _sys
_sys.dont_write_bytecode = True

import json, os, subprocess, sys
from pathlib import Path
from playwright.sync_api import sync_playwright

WS = Path(__file__).resolve().parents[3]
OUT = Path("/tmp/taiga-formats"); OUT.mkdir(parents=True, exist_ok=True)
QS, LJ = WS / "QuantSkill", WS / "lumenJourney"
VIEW = {"width": 1440, "height": 900}
SEED = ("Math.random = (function(){let a=20260311;return function(){a|=0;a=a+0x6D2B79F5|0;"
        "let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};})();")
HIDE = "::-webkit-scrollbar{display:none} canvas.qs-confetti{display:none!important}"


def page(b, scheme="light"):
    ctx = b.new_context(viewport=VIEW, color_scheme=scheme); ctx.add_init_script(SEED); ctx.set_default_timeout(120000)
    pg = ctx.new_page(); errs = []
    pg.on("pageerror", lambda e: errs.append(str(e)))
    return ctx, pg, errs


def start_assessment(pg):
    pg.click(".qs-hero .qs-btn"); pg.wait_for_timeout(900)
    pg.fill('input[placeholder="Your name"]', "Sam Rivera")
    pg.evaluate("""() => document.querySelectorAll('.qs-pick').forEach(el => {
        const want = /R Prog|Git|Async/.test(el.querySelector('.qs-pick-label').textContent);
        if ((el.getAttribute('aria-pressed') === 'true') !== want) el.click(); })""")
    pg.click('.qs-seg.is-lg button[data-v="quick"]'); pg.click(".qs-setup-foot .qs-btn"); pg.wait_for_timeout(900)
    for c in pg.query_selector_all(".qs-rate-card"): c.query_selector_all(".qs-rate-seg button")[7].click()


def main():
    with sync_playwright() as p:
        b = p.chromium.launch()
        # ---- QuantSkill: standalone HTML
        ctx, pg, errs = page(b)
        pg.goto((QS / "inst/html/quantskill.html").as_uri()); pg.wait_for_timeout(2500); pg.add_style_tag(content=HIDE)
        pg.screenshot(path=str(OUT / "qs-html.png")); print("qs-html", errs); ctx.close()
        # ---- QuantSkill: Quarto (rendered document), Method page with the author's markdown
        ctx, pg, errs = page(b)
        pg.goto((QS / "quarto/quantskill.html").as_uri() + "#/method"); pg.wait_for_timeout(2500); pg.add_style_tag(content=HIDE)
        pg.screenshot(path=str(OUT / "qs-quarto.png")); print("qs-quarto", errs); ctx.close()
        # ---- QuantSkill: Shiny front end against its protocol stand-in
        sys.path.insert(0, str(QS / "dev" / "simulate")); sys.path.insert(0, str(QS / "dev" / "video"))
        import cohort
        init = (QS / "dev/video/assets/shiny_init.json").read_text(encoding="utf-8")
        server = cohort.MockServer(cohort.load_bank(), init, [])
        page_file = OUT / "_qs_shiny.html"
        page_file.write_text(cohort.PAGE.format(www=(QS / "inst/app/www").as_uri()))
        ctx, pg, errs = page(b)
        pg.expose_function("qsServer", lambda raw: server.handle("taiga", raw))
        pg.goto(page_file.as_uri()); pg.wait_for_timeout(2500); pg.add_style_tag(content=HIDE)
        start_assessment(pg)
        pg.click("text=Lock in & start")
        pg.wait_for_selector(".qs-qcard", timeout=30000); pg.wait_for_timeout(900)   # graded by the server; toast with the resume code
        pg.screenshot(path=str(OUT / "qs-shiny.png")); print("qs-shiny", errs); ctx.close()
        # ---- lumenJourney: three builds of the same front end
        subprocess.run(["node", str(LJ / "tools/story-dev/build.mjs"), str(OUT / "_ls_html.html")], check=True, cwd=str(LJ), stdout=subprocess.DEVNULL)
        subprocess.run(["node", str(LJ / "tools/story-dev/build.mjs"), str(OUT / "_ls_shiny.html"), "--mode=shiny"], check=True, cwd=str(LJ), stdout=subprocess.DEVNULL)
        for key, url, setup in [("ls-html", (OUT / "_ls_html.html").as_uri(), False),
                                ("ls-quarto", (LJ / "inst/quarto/lumen-story.html").as_uri(), False),
                                ("ls-shiny", (OUT / "_ls_shiny.html").as_uri(), True)]:
            ctx, pg, errs = page(b, "dark")
            if setup:   # the mock window.Shiny the project's dev notes use for Shiny mode (tools/story-dev/README.md)
                ctx.add_init_script("window.Shiny = { shinyapp: { isConnected: function () { return true; } }, setInputValue: function () {},"
                                    " addCustomMessageHandler: function () {} };")
            pg.goto(url); pg.wait_for_timeout(3500); pg.add_style_tag(content=HIDE)
            if setup:
                pg.click(".ls-setup-btn"); pg.wait_for_timeout(1200)
                # scroll the setup sheet to the data source choice (uploads / server folder: Shiny only)
                print("  shiny-only options:", pg.evaluate("""() => { const t = [...document.querySelectorAll('.ls-sheet *')].filter(e => e.children.length === 0 && /upload|folder|server/i.test(e.textContent));
                    if (t.length) t[0].scrollIntoView({block: 'center'}); return t.slice(0, 6).map(e => e.textContent.trim().slice(0, 60)); }"""))
                pg.wait_for_timeout(800)
            pg.screenshot(path=str(OUT / f"{key}.png")); print(key, errs); ctx.close()
        b.close()


if __name__ == "__main__":
    main()
