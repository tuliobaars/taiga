"""DirectoR promo video, made with QuantSkill's video utility (QuantSkill/dev/video), read-only.

What comes from QuantSkill/dev/video (imported, not copied or edited):
  recorder.py  deterministic 60 fps capture + cursor        (used by shots.py)
  stage/stage.js, stage/stage.css   the motion-graphics engine
  render.py    stage -> frames -> H.264, in parallel chunks  (prepare, duration_of, render_range)
  music.py     original score + UI clicks from shot markers   (teaser())
  ff.py, fonts.py   ffmpeg/encoder helpers, Inter font
What is DirectoR-specific (this folder): shots.py (what to film), stage/teaser.js (the edit), and the mux
step below (make.py's mux_teaser() hard-codes QuantSkill's file names; same targets here, -14 LUFS / -1 dBTP,
reached with a two-pass loudnorm and a limiter).

    bash taiga-design-system/tools/bench/build_director.sh        # the DirectoR bench (once)
    python3 taiga-design-system/tools/video/directoR/make_promo.py [--reshoot] [--preview]
Output: DirectoR/media/DirectoR_teaser_30s.mp4 (+ _poster.png, README.md)
"""
from __future__ import annotations

import sys as _sys
_sys.dont_write_bytecode = True          # never write __pycache__ into the projects whose modules are imported

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
WS = HERE.parents[3]
QSV = WS / "QuantSkill" / "dev" / "video"
os.environ.setdefault("QS_VIDEO_BUILD", "/tmp/drvideo")           # a separate build folder: QuantSkill's own footage is untouched
BUILD = Path(os.environ["QS_VIDEO_BUILD"])
MEDIA = WS / "DirectoR" / "media"
NAME = "DirectoR_teaser_30s"
sys.path.insert(0, str(QSV))
import ff as FF  # noqa: E402
import render  # noqa: E402
import music  # noqa: E402


def stage_src():
    """render.prepare() reads <HERE>/stage/{stage.css,stage.js,<name>.js}: give it QuantSkill's engine + DirectoR's edit"""
    src = BUILD / "stage_src" / "stage"
    src.mkdir(parents=True, exist_ok=True)
    for f in ("stage.js", "stage.css"):
        shutil.copy(QSV / "stage" / f, src / f)
    shutil.copy(HERE / "stage" / "teaser.js", src / "teaser.js")
    render.HERE = str(src.parent)
    return src


def do_render(chunks=3):
    page = render.prepare("teaser")
    dur = render.duration_of("teaser", page)           # also writes render/teaser_clips.json (used for the UI click sounds)
    f0, f1 = 0, int(round(dur * render.FPS)); step = (f1 - f0 + chunks - 1) // chunks
    jobs, parts = [], []
    for i in range(chunks):
        s, e = f0 + i * step, min(f1, f0 + (i + 1) * step)
        p = BUILD / "render" / f"teaser_part{i}.mp4"; p.parent.mkdir(parents=True, exist_ok=True)
        parts.append(p); jobs.append(("teaser", page, s, e, str(p), False))
    t = time.time()
    with ProcessPoolExecutor(max_workers=chunks) as ex:
        for errs in ex.map(render.render_range, jobs):
            if errs: print("page errors:", errs[:5])
    lst = BUILD / "render" / "teaser_parts.txt"
    lst.write_text("".join("file '%s'\n" % p for p in parts))
    out = BUILD / "render" / "teaser_video.mp4"
    subprocess.run([FF.ffmpeg(), "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(out)], check=True)
    print("rendered", out, "in %.0fs" % (time.time() - t))
    return out


def do_music():
    x = music.teaser(dur=30.0, bpm=120.0)
    p = BUILD / "audio" / "teaser_music.wav"
    music.write(str(p), x)
    print("music:", p, "UI clicks at", music.click_times("teaser"))
    return p


def do_mux(video, audio):
    MEDIA.mkdir(parents=True, exist_ok=True)
    out = MEDIA / f"{NAME}.mp4"
    # targets as QuantSkill's make.py mux_teaser() (music only, -14 LUFS, TP -1 dB, LRA 9, AAC 256k, faststart),
    # in two passes (measure, then linear normalisation) so the true peak lands on target
    meas = subprocess.run([FF.ffmpeg(), "-hide_banner", "-nostats", "-i", str(audio), "-af", "loudnorm=I=-14:TP=-1.0:LRA=9:print_format=json",
                           "-f", "null", "-"], capture_output=True, text=True).stderr
    m = json.loads(meas[meas.rindex("{"):meas.rindex("}") + 1])
    ln = ("loudnorm=I=-14:TP=-1.0:LRA=9:measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s:linear=true"
          % (m["input_i"], m["input_tp"], m["input_lra"], m["input_thresh"], m["target_offset"]))
    subprocess.run([FF.ffmpeg(), "-y", "-loglevel", "error", "-i", str(video), "-i", str(audio),
                    "-filter_complex", "[1:a]%s,alimiter=limit=0.78:level=false[a]" % ln,      # ~2.2 dB headroom: the AAC encoder adds ~1 dB of inter-sample overshoot
                    "-map", "0:v", "-map", "[a]", "-c:v", "copy",
                    "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-t", "30", "-movflags", "+faststart", str(out)], check=True)
    subprocess.run([FF.ffmpeg(), "-y", "-loglevel", "error", "-ss", "27.8", "-i", str(out), "-frames:v", "1", str(MEDIA / f"{NAME}_poster.png")], check=True)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reshoot", action="store_true")
    ap.add_argument("--preview", action="store_true", help="one still per second to BUILD/preview (no video)")
    ap.add_argument("--skip-render", action="store_true", help="reuse the rendered picture; re-score and re-mux only")
    a = ap.parse_args()
    done = BUILD / "shots_done.json"
    if a.reshoot or not done.exists():
        subprocess.run([sys.executable, str(HERE / "shots.py")], check=True, env=dict(os.environ))
    stage_src()
    if a.preview:
        page = render.prepare("teaser")
        paths, errs = render.preview_frames("teaser", [i + 0.5 for i in range(30)], str(BUILD / "preview"))
        print(len(paths), "stills; errors:", errs[:5]); return
    video = BUILD / "render" / "teaser_video.mp4" if a.skip_render else do_render()
    if a.skip_render: render.duration_of("teaser", render.prepare("teaser"))      # refresh the cut list used for click sounds
    audio = do_music()
    out = do_mux(video, audio)
    print("done:", out)


if __name__ == "__main__":
    main()
