# DirectoR promo, made with QuantSkill's video utility

This folder drives `QuantSkill/dev/video` (imported, never edited) to make DirectoR's promo video.
Only three things are DirectoR-specific:

| File | Role |
|---|---|
| `shots.py` | Records the footage with QuantSkill's `recorder.Recorder` and `recorder.Cursor` against the DirectoR bench site (`../../bench/`). Groups: `library` (typing a source, Create film, autopilot), `pages` (source, story with the live preview, shots, sound, look), `export` (render and dock). One `goto()` per recorder (the virtual clock cannot restart), with pages switched in place. |
| `stage/teaser.js` | The edit, for QuantSkill's stage engine (`Stage.bg / clip / text / custom / punch / flash`). It follows the form of QuantSkill's teaser score (`music.py teaser()`: intro 0–4 s, drop at 4, whooshes at 7.5/9.5/14/22, break 18–20, lift 20–26, final hit 26). DirectoR's colours are injected as one extra class (`.dgrad`); `stage.css` is not changed. |
| `make_promo.py` | Copies QuantSkill's `stage.js`/`stage.css` and this timeline into `$QS_VIDEO_BUILD/stage_src/` and points `render.HERE` at it; renders with `render.prepare`, `render.duration_of`, `render.render_range`; scores with `music.teaser()`; muxes into `DirectoR/media/` with `make.py mux_teaser()`'s targets (−14 LUFS, −1 dBTP). It uses two-pass `loudnorm` plus a limiter, because the AAC encoder adds about 1 dB of inter-sample overshoot. |

```sh
bash ../../bench/build_director.sh                 # the DirectoR bench (engine projects + webR render + site)
python3 make_promo.py                              # footage (first run), render, music, mux
python3 make_promo.py --skip-render                # re-score and re-mux only
python3 make_promo.py --preview                    # one still per second in $QS_VIDEO_BUILD/preview
```

Marker names matter: `music.py click_times()` puts a UI click sound at every shot marker except a fixed
list (`type`, `sweep`, `reveal`, …). Markers that are not clicks use names from that list (`sweep` for
the hover on the Shots page, `reveal` for the finished render).
