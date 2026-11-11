"""QuantSkill feature screenshots, from the real standalone HTML build (inst/html/quantskill.html).

Reuses the proven flows of QuantSkill/dev/screens.py by importing it and redirecting its output
(module globals FIG/DOCS and the save()/page() hooks) to a temporary folder, so QuantSkill's own
man/figures and docs/screenshots are never written. Adds a team-dashboard shot with the 47-person
simulated cohort and an interview-mode shot.

    python3 taiga-design-system/tools/screens/quantskill.py
"""
from __future__ import annotations

import sys as _sys
_sys.dont_write_bytecode = True          # never write __pycache__ into the projects whose modules are imported

import glob
import shutil
import sys
import tempfile
from pathlib import Path

from playwright.sync_api import sync_playwright

sys.path.insert(0, str(Path(__file__).parent))
import common as C  # noqa: E402

QS = C.WS / "QuantSkill"
sys.path.insert(0, str(QS / "dev"))
import screens as S  # noqa: E402  (QuantSkill/dev/screens.py, imported read-only)

TMP = Path(tempfile.mkdtemp(prefix="taiga-qs-"))
M = C.Manifest("QuantSkill", "lumen")
SRC = "inst/html/quantskill.html (standalone build of srcjs/)"
ORDER = ["01-landing", "02-landing-dark", "03-question", "04-scenario", "05-feedback", "06-results", "07-results-areas",
         "08-team-dashboard", "09-interview", "10-pdf-report"]
META = {
    "landing": ("01-landing", "Landing", "Hero with the twelve skill areas orbiting the headline; glass nav, drifting colour blobs.", "light"),
    "landing_dark": ("02-landing-dark", "Landing, dark", "The same page in the true-black dark theme.", "dark"),
    "question": ("03-question", "Adaptive question", "A SAS log question with syntax-highlighted code and the three-level confidence stake.", "light"),
    "scenario": ("04-scenario", "Multi-step scenario", "A Git scenario: each decision is locked in before the situation moves on.", "light"),
    "feedback": ("05-feedback", "Scenario debrief", "Feedback after the last decision: the whole path explained, with partial credit.", "light"),
    "results": ("06-results", "Results", "Predicted vs measured on a 0-10 scale with a margin of error, per skill area.", "light"),
    "results_areas": ("07-results-areas", "Results by area", "Area scores, problem-solving scores and the reality-check view.", "light"),
}


def save(pg, name, docs=True, fig=True, **kw):
    if name not in META:
        return
    path = TMP / f"{name}.png"
    pg.screenshot(path=str(path), **kw)
    key, title, cap, theme = META[name]
    M.add(path, key, title, cap, "live", SRC, theme)


def page(p, theme="light"):
    b = p.chromium.launch()
    ctx = C.new_context(b, theme)
    ctx.add_init_script("document.addEventListener('DOMContentLoaded', () => { const st = document.createElement('style');"
                        " st.textContent = 'canvas.qs-confetti{display:none!important}" + C.NO_SCROLLBARS + "'; document.head.appendChild(st); });")
    pg = ctx.new_page()
    pg._taiga_errors = C.ErrorLog(pg, "QuantSkill " + theme)
    pg.goto(S.URL)
    pg.wait_for_timeout(2500)
    pg.add_style_tag(content="html{scroll-behavior:auto!important}")
    return b, pg


def team(p):
    b, pg = page(p)
    pg.click('.qs-nav-link[data-path="team"]'); pg.wait_for_timeout(900)
    files = sorted(glob.glob(str(QS / "examples" / "simulated-cohort" / "server-results" / "completed" / "*.json")))
    pg.set_input_files(".qs-drop input[type=file]", files); pg.wait_for_timeout(3000)
    y = pg.evaluate("() => { const e = [...document.querySelectorAll('h3, .qs-card-title, h2')].find(x => /Self-rating vs measured/.test(x.textContent)); return e ? e.getBoundingClientRect().top + scrollY : 560; }")
    pg.evaluate(f"window.scrollTo(0, {y} - 150)"); pg.wait_for_timeout(2500)
    shot = TMP / "team.png"; pg.screenshot(path=str(shot), timeout=180000)
    M.add(shot, "08-team-dashboard", "Team dashboard",
          f"{len(files)} completed assessments from the simulated cohort: self-rating vs measured, per person and area.", "live", SRC)
    pg._taiga_errors.report(); b.close()


def interview(p):
    b, pg = page(p)
    pg.evaluate("location.hash='#/interview'"); pg.wait_for_timeout(1200)
    pg.fill('input[placeholder="Candidate or session name"]', "Jordan Lee")
    for idx in (0, 1, 2):
        pg.locator(".qs-alloc-cat").nth(idx).locator("text=+1 spread").click(); pg.wait_for_timeout(250)
    pg.evaluate("window.scrollTo(0, 0)"); pg.wait_for_timeout(400)
    pg.click(".qs-setup-foot .qs-btn"); pg.wait_for_timeout(2500)
    pg.click("text=Start interview"); pg.wait_for_timeout(1500)
    pg.click(".qs-grade.is-r4"); pg.wait_for_timeout(1200)
    pg.evaluate("window.scrollTo(0, 0)"); pg.wait_for_timeout(800)
    shot = TMP / "interview.png"; pg.screenshot(path=str(shot), timeout=180000)
    M.add(shot, "09-interview", "Interview mode",
          "Live interview: questions with expected responses and a 0-5 rubric per answer.", "live", SRC)
    pg._taiga_errors.report(); b.close()


def question(p):
    """a code question with the confidence stake, unanswered (independent of the adaptive draw in S.assessment)"""
    b, pg = page(p)
    pg.goto(S.URL + "#/assess"); pg.wait_for_timeout(1000)
    pg.add_style_tag(content="html{scroll-behavior:auto!important}")
    pg.fill('input[placeholder="Your name"]', "Alex Morgan")
    for el in pg.query_selector_all(".qs-pick"):
        want = any(a.lower() in el.inner_text().lower() for a in ("R Prog",))
        if (el.get_attribute("aria-pressed") == "true") != want:
            el.click()
    pg.click('.qs-seg.is-lg button[data-v="quick"]')
    pg.click(".qs-setup-foot .qs-btn"); pg.wait_for_timeout(900)
    for c in pg.query_selector_all(".qs-rate-card"):
        c.query_selector_all(".qs-rate-seg button")[8].click()
    pg.click("text=Lock in & start"); pg.wait_for_timeout(1500)
    for _ in range(12):                       # skip (answer) items until one shows code
        pg.wait_for_selector(".qs-qcard")
        if pg.query_selector(".qs-qcard pre, .qs-qcard code.qs-code, .qs-code"):
            break
        it = pg.evaluate("""() => { const s = JSON.parse(localStorage.getItem('quantskill.session'));
            const it = QuantSkill.app.state.bank.byId[s.current.itemId]; return {type: it.type, answer: it.answer, scores: it.scores}; }""")
        if it["type"] in ("single", "sjt"):
            best = it["scores"].index(max(it["scores"])) if it["scores"] else it["answer"][0]
            pg.click(f'.qs-option[data-oi="{best}"]')
        elif it["type"] == "multi":
            for oi in it["answer"]: pg.click(f'.qs-option[data-oi="{oi}"]')
        else:
            pg.click(".qs-option >> nth=0")
        pg.click(".qs-stake.is-mid"); pg.wait_for_timeout(300)
        pg.click(".qs-feedback .qs-btn"); pg.wait_for_timeout(900)
    pg.wait_for_timeout(1200)
    shot = TMP / "question.png"; pg.screenshot(path=str(shot))
    M.add(shot, "03-question", "Adaptive question", "An adaptive R question with code, answered with a confidence stake (low / mid / high).", "live", SRC)
    pg._taiga_errors.report(); b.close()


def main():
    S.save, S.page, S.FIG, S.DOCS, S.TMP = save, page, TMP / "fig", TMP / "docs", TMP
    (TMP / "fig").mkdir(); (TMP / "docs").mkdir()
    parts = sys.argv[1:] or ["landing", "assessment", "question", "team", "interview"]
    with sync_playwright() as p:
        if "landing" in parts: S.landing(p)
        if "assessment" in parts: S.assessment(p)    # question, scenario, feedback, results, results_areas, pdf pages (-> TMP/fig)
        if "question" in parts and not (M.dir / "03-question.jpg").exists(): question(p)
        if "team" in parts: team(p)
        if "interview" in parts: interview(p)
    cover = TMP / "fig" / "pdf_cover.jpeg"     # QuantSkill/dev/screens.py writes JPEG figures
    if cover.exists():
        M.add(cover, "10-pdf-report", "PDF report", "Cover of the PDF report, organised by skill category.", "live", SRC)
    M.save(ORDER)
    shutil.rmtree(TMP, ignore_errors=True)


if __name__ == "__main__":
    main()
