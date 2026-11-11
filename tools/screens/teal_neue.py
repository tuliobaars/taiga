"""teal_neue feature screenshots, from the test bench (see tools/bench/README.md).

Real: header, module nav (58 modules from teal_neue_modules()), command-bar index, the study overview
(R/overview.R on the bundled ADaM cache), footer, TLG Catalog pages and their server-rendered headers
and "Show R code" dialog, all from the package's unmodified R code (webR); teal_neue.css/js and fonts.
Stand-in: teal's page chrome mirrors its Bootstrap markup; the Kaplan-Meier module view is a bench
layout with a base-R plot of the real ADTTE data (teal.modules.clinical/ggplot2 are not available).

    bash /tmp/neue_build.sh teal_neue          (tools/bench/build_neue.sh)
    python3 taiga-design-system/tools/screens/teal_neue.py
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

TMP = Path(tempfile.mkdtemp(prefix="taiga-tn-"))
M = C.Manifest("teal_neue", "neue")
SRC = "bench: R/app_ui.R, R/app_modules.R, R/overview.R, R/tlg_catalog.R (webR, shim.R) + inst/www/teal_neue.{css,js}"
SRC_KM = SRC + "; stand-in module layout and base-R plot of the real ADTTE data"
ORDER = ["01-home", "02-home-dark", "03-analysis-module", "04-command-bar", "05-where-to", "06-appearance", "07-tlg-catalog",
         "08-shortcuts", "09-module-dark"]

SHOW_TAB = """(re) => { const a = [...document.querySelectorAll('[data-bs-toggle=tab]')].find(x => new RegExp(re).test(x.textContent.trim()));
  bootstrap.Tab.getOrCreateInstance(a).show();
  document.querySelectorAll('.dropdown-menu.show').forEach(m => { const t = m.parentElement.querySelector('[data-bs-toggle=dropdown]'); if (t) bootstrap.Dropdown.getOrCreateInstance(t).hide(); });
  return a.textContent.trim(); }"""


def open_page(b, theme="light"):
    ctx = C.new_context(b, theme)
    if theme == "dark":
        ctx.add_init_script("try { localStorage.setItem('teal_neue:color-mode', 'dark'); } catch (e) {}")
    pg = ctx.new_page()
    log = C.ErrorLog(pg, "teal_neue " + theme)
    pg.goto(SRV.url + "index.html"); pg.wait_for_timeout(2600)
    pg.evaluate("() => bench.load('outputs/default')"); pg.wait_for_timeout(400)
    return ctx, pg, log


def shot(pg, key, title, caption, src=SRC, theme="light"):
    p = TMP / f"{key}.png"; pg.screenshot(path=str(p))
    M.add(p, key, title, caption, "bench", src, theme)


def key(pg, k, wait=1400):
    pg.mouse.click(1300, 860)            # focus the page (not an input) so the app's shortcuts fire
    pg.keyboard.press(k); pg.wait_for_timeout(wait)


SRV = None


def main():
    global SRV
    SRV = Server(SITES / "teal_neue")
    with sync_playwright() as p:
        b = p.chromium.launch()
        ctx, pg, log = open_page(b)
        shot(pg, "01-home", "Study at a glance", "Home page: key figures, demographics, safety and efficacy by arm, each linking to its module.")
        pg.click("text=Where to?"); pg.wait_for_timeout(1200)
        shot(pg, "05-where-to", "Where to?", "Every module, nested by section with its tint, from the command bar.")
        pg.keyboard.press("Escape"); pg.wait_for_timeout(600)
        key(pg, "a", 1200)
        shot(pg, "06-appearance", "Appearance", "Text size, spacing, accent, corners, contrast, canvas and motion, remembered per user.")
        pg.keyboard.press("Escape"); pg.wait_for_timeout(600)
        key(pg, "Shift+Slash", 1200)
        shot(pg, "08-shortcuts", "Keyboard shortcuts", "Every action has a key: jump, home, previous/next module, focus, pins, links.")
        pg.keyboard.press("Escape"); pg.wait_for_timeout(600)
        pg.evaluate(SHOW_TAB, "^Kaplan"); pg.wait_for_timeout(1600)
        pg.mouse.move(700, 380); pg.wait_for_timeout(900)
        shot(pg, "03-analysis-module", "Analysis module", "A module with its breadcrumb, section tint, plot tools on hover and the filter panel (bench stand-in for the module layout and plot: base R on the real ADTTE data).", SRC_KM)
        pg.mouse.click(1300, 860); pg.wait_for_timeout(300)
        pg.keyboard.press("Control+k"); pg.wait_for_timeout(700)
        pg.keyboard.type("kaplan", delay=60); pg.wait_for_timeout(900)
        shot(pg, "04-command-bar", "Command bar", "Ctrl/Cmd+K: fuzzy search over every module, TLG output and action.")
        pg.keyboard.press("Escape"); pg.wait_for_timeout(500)
        pg.evaluate(SHOW_TAB, "^Adverse Events$"); pg.wait_for_timeout(1500)
        # (the output itself needs tern, which the bench cannot run: the page is shown with its "Show R code" dialog)
        modal = (Path("/tmp/taiga-bench/teal_neue/modal_tlg.html")).read_text()
        pg.evaluate("""(h) => { const d = document.createElement('div'); d.innerHTML = h; document.body.appendChild(d.firstElementChild);
            bootstrap.Modal.getOrCreateInstance(document.getElementById('shiny-modal')).show(); }""", modal)
        pg.wait_for_timeout(1200)
        shot(pg, "07-tlg-catalog", "TLG Catalog", "One page per topic with searchable outputs; Show R code gives the complete, runnable code (here AET01).")
        log.report(); ctx.close()

        ctx, pg, log = open_page(b, "dark")
        shot(pg, "02-home-dark", "Dark mode", "The ink-blue dark palette; plots stay white paper so they match their R code.", theme="dark")
        pg.evaluate(SHOW_TAB, "^Kaplan"); pg.wait_for_timeout(1600)
        pg.mouse.move(1300, 860); pg.wait_for_timeout(500)
        shot(pg, "09-module-dark", "Module, dark", "The analysis module in dark mode: ruled panels on the dot-grid canvas, plots kept white (bench stand-in layout and plot).", SRC_KM, theme="dark")
        log.report(); ctx.close()
        b.close()
    SRV.close()
    M.save(ORDER)


if __name__ == "__main__":
    main()
