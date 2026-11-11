"""RockShiny feature screenshots, from the test bench (see tools/bench/README.md).

Real: the page (app.R's ui(): bslib sidebar, accordion, brand, shortcuts; webR), the highway
(inst/highway: output binding, clock, renderers, overlays), and the charts: the bundled songs parsed by
RockShiny's Python reference implementation (the test mirror of its R parser), with the library labels,
arrangements and sections the server would push. Stand-in: the audio is a click track at every note
onset (as in the project's frontend tests), since Wwise audio needs vgmstream.

    PYTHONDONTWRITEBYTECODE=1 python3 tools/bench/rockshiny_fixtures.py && bash tools/bench/build_rockshiny.sh
    python3 taiga-design-system/tools/screens/rockshiny.py
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

TMP = Path(tempfile.mkdtemp(prefix="taiga-rs-"))
M = C.Manifest("RockShiny", "lumen")
SRC = "bench: app.R ui() + R/mod_*.R (webR, shim.R) + inst/{app,highway,dropzone}; charts from songs_all/ via tests/reference"
ORDER = ["01-highway", "02-bass", "03-practice-loop", "04-piano", "05-harmonica", "06-html-renderer"]
SONGS = json.loads((SITES / "rockshiny" / "songs.json").read_text())

LOAD = """async ([chart, song, t, opts, inst]) => {
  const el = document.querySelector('.rs-highway'); const ob = bench.outputBindings.find(x => /highway/i.test(x.name));
  const txt = await (await fetch('charts/' + chart + '.json')).text();
  ob.b.renderValue(el, { chart: txt, options: Object.assign({ lookahead: 3, renderer: 'canvas', lyrics: true, showFretNumbers: true }, opts || {}) });
  await new Promise(r => setTimeout(r, 600));
  // what the server pushes after a song loads: the library pick, arrangements, section pickers (updateSelectInput)
  const setSel = (id, opts, value) => { const s = document.getElementById(id); if (!s) return;
    if (opts) s.innerHTML = opts.map(o => '<option value="' + o[0] + '">' + o[1] + '</option>').join(''); s.value = value; };
  const lib = document.getElementById('import-library');
  if (lib) { const o = [...lib.options].find(x => x.textContent === song.library_label); if (o) lib.value = o.value; }
  setSel('player-arrangement', song.arrangements.map(a => [a.id, a.label]), song.arrangement);
  const secs = song.sections.map((l, i) => [i, l]);
  const cur = Math.max(0, song.sections.length - 1 - [...song.sections].reverse().findIndex(l => { const m = l.match(/(\\d+):(\\d+)$/); return +m[1] * 60 + +m[2] <= t; }));
  setSel('player-loop_from', secs, cur); setSel('player-loop_to', secs, cur);
  if (inst) { const r = document.querySelector('input[type=radio][value="' + inst + '"]'); if (r) r.checked = true; }
  bench.send('rs-highway', { id: el.id, cmd: 'audio', args: { url: 'audio/' + chart.replace(/_(piano|harmonica)$/, '_lead') + '.ogg', songKey: song.songKey, kind: 'full' } });
  await new Promise(r => setTimeout(r, 1200));
  bench.send('rs-highway', { id: el.id, cmd: 'seek', args: { time: t } });
  return el.id; }"""


def state(b, chart, song_tag, t, opts=None, inst=None, after=None):
    ctx = C.new_context(b, "dark")
    pg = ctx.new_page()
    log = C.ErrorLog(pg, "RockShiny " + chart)
    pg.goto(SRV.url + "index.html"); pg.wait_for_timeout(1500)
    pg.evaluate(LOAD, [chart, SONGS[song_tag], t, opts, inst]); pg.wait_for_timeout(1800)
    if after: pg.evaluate(after); pg.wait_for_timeout(1200)
    return ctx, pg, log


def shot(pg, key, title, caption):
    p = TMP / f"{key}.png"; pg.screenshot(path=str(p))
    M.add(p, key, title, caption, "bench", SRC, "dark")


SRV = None


def main():
    global SRV
    SRV = Server(SITES / "rockshiny")
    with sync_playwright() as p:
        b = p.chromium.launch(args=["--autoplay-policy=no-user-gesture-required"])
        ctx, pg, log = state(b, "wywh_lead", "wywh_lead", 63.4)
        shot(pg, "01-highway", "Note highway", "Wish You Were Here, lead: the 3-D highway with the song's album art, section, tuning and timeline.")
        log.report(allow=("play() failed",)); ctx.close()

        ctx, pg, log = state(b, "sultans_bass", "sultans_bass", 101.0)
        shot(pg, "02-bass", "Bass", "Sultans of Swing, bass: four strings, chords and techniques drawn on the same highway.")
        log.report(); ctx.close()

        sec = SONGS["sultans_lead"]["sections"]
        loop = """() => { const el = document.querySelector('.rs-highway');
          const sw = document.getElementById('player-loop'); if (sw) sw.checked = true;
          bench.send('rs-highway', { id: el.id, cmd: 'settings', args: { settings: { practice: { loop: true, start: 246.0, end: 262.0, leadIn: 2, ramp: 0.05 }, playbackRate: 0.75 } } });
          const sp = document.getElementById('player-speed'); if (sp) sp.value = '0.75';
          bench.send('rs-highway', { id: el.id, cmd: 'seek', args: { time: 250.5 } }); }"""
        ctx, pg, log = state(b, "sultans_lead", "sultans_lead", 250.5, after=loop)
        shot(pg, "03-practice-loop", "Practice loop", "Loop a stretch with a lead-in, slow it to 75%, speed up on each pass.")
        log.report(); ctx.close()

        ctx, pg, log = state(b, "wywh_piano", "wywh_lead", 63.4, inst="piano")
        shot(pg, "04-piano", "Piano", "Any guitar part on a 3-D keyboard highway, hands coloured.")
        log.report(); ctx.close()

        ctx, pg, log = state(b, "sultans_harmonica", "sultans_lead", 101.0, inst="harmonica")
        shot(pg, "05-harmonica", "Harmonica", "The same part on a 10-hole harmonica: best harp key, blow/draw tab, bends.")
        log.report(); ctx.close()

        ctx, pg, log = state(b, "getlucky_lead", "getlucky_lead", 48.0, opts={"renderer": "dom"})
        shot(pg, "06-html-renderer", "HTML/SVG renderer", "Get Lucky on the second, zero-dependency HTML/SVG renderer, switchable at runtime.")
        log.report(); ctx.close()
        b.close()
    SRV.close()
    M.save(ORDER)


if __name__ == "__main__":
    main()
