"""BlockR feature screenshots, from the test bench (see tools/bench/README.md).

Real: the header, module nav, footer and the canvas page (R/canvas.R UI, its config: block registry and
templates), the template graphs (blockr_template_graph), the block statuses (blockr_run, with base-R
stand-ins for the data verbs: data-block row/column counts are true counts on the bundled ADaM data),
the compiled R code (blockr_compile), the SAS code (blockr_sas); blockr.css / blockr_canvas.{css,js} /
blockr_tutorial.js. Stand-ins: table/plot contents (tern, rtables, ggplot2 unavailable: those blocks
show their kind only) and the DT data previews (plain tables of the real first rows).

    bash tools/bench/build_neue.sh BlockR
    python3 taiga-design-system/tools/screens/blockr.py
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright

sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "bench"))
import common as C  # noqa: E402
from sites import SITES, Server  # noqa: E402

TMP = Path(tempfile.mkdtemp(prefix="taiga-bk-"))
M = C.Manifest("BlockR", "neue")
SRC = "bench: R/canvas.R, R/blocks_*.R, R/app_ui.R (webR, shim.R, blockr_standins.R) + inst/www/blockr*.{css,js}"
MSG = Path("/tmp/taiga-bench/BlockR/messages")
ORDER = ["01-canvas-template", "02-canvas-start", "03-derived-columns", "04-code-r", "05-code-sas", "06-listing",
         "07-next-steps", "08-tutorial", "09-dark-explain"]

HELPERS = """
window.bkb = {
  app(view) { return document.querySelector('.bk-view[data-view="' + (view || 'main') + '"] .bk-app'); },
  ed(view) { return this.app(view)._bk; },
  ns(view) { return this.app(view).getAttribute('data-ns'); },
  data(msg, view) { bench.send('blockr-data', Object.assign({}, msg, { ns: this.ns(view) })); },
  status(st, view) { const ed = this.ed(view); st = Object.assign({}, st, { ns: this.ns(view), rev: ed.rev }); bench.send('blockr-status', st); },
  graph(msg, st, view) { bench.send('blockr-graph', Object.assign({}, msg, { ns: this.ns(view) })); this.status(st, view); },
  // a canvas built in the browser (one dataset block): answer with the precomputed status of that dataset, keyed by the block's id
  dsStatus(st, view) { const ed = this.ed(view); const n = ed.g.nodes.find(x => x.type === 'dataset'); const one = st.nodes.n1;
    this.status(Object.assign({}, st, { nodes: { [n.id]: one } }), view); return n.id; },
  fill(id, html) { return bench.fill(id, html); },
  full(view) { const ed = this.ed(view); ed.toggleFull(true); return ed; },
  pick(fn, view) { const ed = this.ed(view); const n = ed.g.nodes.find(x => x.fn === fn || x.dataset === fn); ed.select(n.id); ed.showPane('block'); return n.id; }
};
"""


def M_(name): return json.loads((MSG / f"{name}.json").read_text())


def prev(tpl, nid):
    p = Path(f"/tmp/taiga-bench/BlockR/previews/{tpl}_{nid}.html")
    return p.read_text() if p.exists() else ""


def open_page(b, theme="light"):
    ctx = C.new_context(b, theme)
    if theme == "dark":
        ctx.add_init_script("try { localStorage.setItem('blockr:color-mode', 'dark'); localStorage.setItem('teal_neue:color-mode', 'dark'); } catch (e) {}")
    ctx.add_init_script("try { localStorage.setItem('blockr:tutorial:seen', '1'); } catch (e) {}")
    pg = ctx.new_page()
    log = C.ErrorLog(pg, "BlockR " + theme)
    pg.goto(SRV.url + "index.html"); pg.wait_for_timeout(2200)
    pg.evaluate(HELPERS)
    pg.evaluate("(m) => bkb.data(m)", M_("data")); pg.wait_for_timeout(700)
    return ctx, pg, log


def load_tpl(pg, tpl, full=True, zoom=None):
    pg.evaluate("([g, s]) => bkb.graph(g, s)", [M_("graph_" + tpl), M_("status_" + tpl)]); pg.wait_for_timeout(900)
    if full:
        pg.evaluate("() => { const ed = bkb.full(); ed.fit(false); }"); pg.wait_for_timeout(700)
    if zoom:
        pg.evaluate("(k) => bkb.ed().zoomTo(k)", zoom); pg.wait_for_timeout(500)
    pg.wait_for_timeout(4200)          # the "Loaded ..." toast leaves


def select(pg, tpl, fn, zoom=None):
    nid = pg.evaluate("(fn) => bkb.pick(fn)", fn); pg.wait_for_timeout(600)
    html = prev(tpl, nid)
    if html: pg.evaluate("(h) => bkb.fill(bkb.ns() + 'preview', h)", html)
    pg.wait_for_timeout(600)
    return nid


def shot(pg, key, title, caption, theme="light"):
    p = TMP / f"{key}.png"; pg.screenshot(path=str(p))
    M.add(p, key, title, caption, "bench", SRC, theme)


SRV = None


def main():
    global SRV
    SRV = Server(SITES / "BlockR")
    with sync_playwright() as p:
        b = p.chromium.launch()
        # the empty canvas in the app: header, tabs, featured templates, palette
        ctx, pg, log = open_page(b)
        pg.wait_for_timeout(600)
        shot(pg, "02-canvas-start", "Start", "An empty canvas: featured TLG templates, all 135 templates, or start from a dataset; the block palette on the left.")
        log.report(); ctx.close()

        # AET02 on the canvas, the ADAE filter selected (plain-language conditions, real row counts)
        ctx, pg, log = open_page(b)
        load_tpl(pg, "AET02")
        pg.evaluate("() => { const ed = bkb.ed(); ed.fit(false); }"); pg.wait_for_timeout(300)
        nid = pg.evaluate("() => { const ed = bkb.ed(); const n = ed.g.nodes.filter(x => x.fn === 'filter')[1]; ed.select(n.id); ed.showPane('block'); return n.id; }")
        pg.evaluate("(h) => bkb.fill(bkb.ns() + 'preview', h)", prev("AET02", nid)); pg.wait_for_timeout(900)
        shot(pg, "01-canvas-template", "A template as blocks", "AET02 on the canvas: stacks of blocks wired together, row counts on the wires, the selected filter in plain language.")
        pg.evaluate("() => bkb.ed().showPane('code')"); pg.wait_for_timeout(900)
        shot(pg, "04-code-r", "Show R code", "The canvas as complete, runnable R code, updated as you edit; edit the code and draw it back as blocks.")
        # the SAS translation: the Code pane's switch asks the server (input$lang); the bench answers with blockr_sas()
        pg.evaluate("""() => { const b = [...document.querySelectorAll('.bk-app.bk-full [data-pane="code"] button, .bk-app.bk-full .bk-seg button')].find(x => /^\\s*SAS\\s*$/.test(x.textContent)); if (b) b.click(); return !!b; }""")
        pg.wait_for_timeout(500)
        pg.evaluate("(m) => { const ed = bkb.ed(); bench.send('blockr-sas', Object.assign({}, m, { ns: bkb.ns(), rev: ed.status.rev })); }", M_("sas_AET02"))
        pg.wait_for_timeout(900)
        shot(pg, "05-code-sas", "SAS translation", "The same canvas as SAS (DATA steps, PROC SQL, PROC REPORT), for SAS users and double programming.")
        log.report(); ctx.close()

        # AET01: derived flags as editable rows
        ctx, pg, log = open_page(b)
        load_tpl(pg, "AET01")
        select(pg, "AET01", "mutate")
        shot(pg, "03-derived-columns", "Derived columns", "AET01: the New columns block, its eleven derived flags editable as rows, and its output.")
        log.report(); ctx.close()

        # AEL02: a listing as the result
        ctx, pg, log = open_page(b)
        load_tpl(pg, "AEL02")
        res = M_("status_AEL02")["result"]
        pg.evaluate("() => bkb.ed().showPane('result')"); pg.wait_for_timeout(400)
        pg.evaluate("(h) => bkb.fill(bkb.ns() + 'result', h)", prev("AEL02", res)); pg.wait_for_timeout(800)
        shot(pg, "06-listing", "A listing", "AEL02: the listing of adverse events as the canvas's result (rows shown from the bundled data).")
        log.report(); ctx.close()

        # from a dataset: the + under a stack suggests what to do next
        ctx, pg, log = open_page(b)
        pg.evaluate("""() => { const ed = bkb.ed(); const n = { id: 'n1', type: 'dataset', dataset: 'ADAE' };
            bench.send('blockr-graph', { ns: bkb.ns(), graph: { version: 1, nodes: [n], result: null, title: 'Serious adverse events' } }); }""")
        pg.wait_for_timeout(600)
        pg.evaluate("(s) => bkb.dsStatus(s)", M_("status_ds_ADAE")); pg.wait_for_timeout(500)
        pg.evaluate("() => { const ed = bkb.full(); ed.fit(false); ed.zoomTo(1); }"); pg.wait_for_timeout(4300)
        pg.click(".bk-app.bk-full .bk-add-next"); ok = True
        pg.wait_for_timeout(1000)
        print("   next-step button:", ok)
        shot(pg, "07-next-steps", "What next?", "The + under a stack suggests next steps for its rows, including recipes that add and wire several blocks.")
        log.report(); ctx.close()

        # the Tutorial
        ctx, pg, log = open_page(b)
        pg.click(".bk-tutorial-btn"); pg.wait_for_timeout(1200)
        pg.evaluate("(m) => bkb.data(m, 'tutorial')", M_("data")); pg.wait_for_timeout(1200)
        shot(pg, "08-tutorial", "Tutorial", "Eight lessons on a canvas of their own, from Meet the canvas to Derive your own column.")
        log.report(); ctx.close()

        # dark mode (lifted slate), with the "What is this?" explanation of a block
        ctx, pg, log = open_page(b, "dark")
        load_tpl(pg, "AET01")
        nid = pg.evaluate("() => { const ed = bkb.ed(); const n = ed.g.nodes.filter(x => x.fn === 'filter')[1]; ed.select(n.id); ed.showPane('block'); return n.id; }")
        pg.evaluate("(h) => bkb.fill(bkb.ns() + 'preview', h)", prev("AET01", nid)); pg.wait_for_timeout(500)
        pg.click('.bk-app.bk-full .bk-block[data-id="%s"] .bk-tip-block' % nid)
        pg.wait_for_timeout(1200)
        shot(pg, "09-dark-explain", "Dark mode", "The lifted slate dark palette; every block explains what it does here, what it works on and what uses it.", "dark")
        log.report(); ctx.close()
        b.close()
    SRV.close()
    M.save(ORDER)


if __name__ == "__main__":
    main()
