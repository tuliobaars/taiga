"""RockShiny bench data, built with RockShiny's own Python reference implementation
(tests/reference/rockshiny_ref.py and instruments_ref.py: the test mirror of R/psarc.R, R/sng.R,
R/arrangement_xml.R, R/instruments.R), read-only, from the bundled songs in songs_all/.

Writes to /tmp/taiga-bench/rockshiny/:
  charts/<tag>.json   chart_json() payloads for the highway (guitar lead, bass, piano, harmonica)
  library.json        the library labels ("Artist — Song") from each song's manifest, as library_choices() builds them

    PYTHONDONTWRITEBYTECODE=1 python3 rockshiny_fixtures.py
"""
import copy, hashlib, json, os, re, sys

sys.dont_write_bytecode = True
RS = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "RockShiny"))
sys.path.insert(0, os.path.join(RS, "tests", "reference"))
import rockshiny_ref as R  # noqa: E402
import instruments_ref as I  # noqa: E402

OUT = "/tmp/taiga-bench/rockshiny"
os.makedirs(os.path.join(OUT, "charts"), exist_ok=True)
LIB = os.path.join(RS, "songs_all")

CHARTS = [("Pink-Floyd_Wish-You-Were-Here_v5_DD_m.psarc", "lead", "wywh_lead", 1.0),
          ("Dire-Straits_Sultans-of-Swing_v443_m.psarc", "lead", "sultans_lead", 1.0),
          ("Dire-Straits_Sultans-of-Swing_v443_m.psarc", "bass", "sultans_bass", 1.0),
          ("DaftPunk_GetLucky_m.psarc", "lead", "getlucky_lead", 1.0)]

built = {}
for fname, part, tag, diff in CHARTS:
    arc = R.Psarc(os.path.join(LIB, fname))
    arr = [p for p in arc.find(r"^songs/arr/.*_%s\.xml$" % part)][0]
    chart = R.build_chart(R.parse_arrangement_xml(arc.read(arr)), diff)
    chart["meta"].update(arrangement=part.title())
    key = hashlib.md5(fname.encode()).hexdigest()
    payload = R.chart_json(chart, key, vocals=R.song_vocals(arc), art=R.song_album_art(arc))
    json.dump(payload, open(os.path.join(OUT, "charts", tag + ".json"), "w"), separators=(",", ":"))
    built[tag] = (chart, key, arc)
    print(tag, len(chart["notes"]), "notes")
for src, tag, inst in [("wywh_lead", "wywh_piano", "piano"), ("sultans_lead", "sultans_harmonica", "harmonica")]:
    chart, key, arc = built[src]
    lane = I.chart_for_instrument(copy.deepcopy(chart), inst)
    json.dump(I.lane_chart_json(lane, key, vocals=R.song_vocals(arc), art=R.song_album_art(arc)),
              open(os.path.join(OUT, "charts", tag + ".json"), "w"), separators=(",", ":"))
    print(tag, len(lane["notes"]), "notes", inst)

# library labels, as library_choices() builds them from each manifest
labels = {}
for f in sorted(os.listdir(LIB)):
    if not f.lower().endswith(".psarc"): continue
    try:
        arc = R.Psarc(os.path.join(LIB, f)); a = None
        for m in arc.find(r"^manifests/.*\.json$"):
            a = list(json.loads(arc.read(m))["Entries"].values())[0]["Attributes"]
            if a.get("SongName"): break
        lab = "%s \u2014 %s" % (a.get("ArtistName") or "Unknown artist", a["SongName"])
        labels[f] = {"label": lab, "album": a.get("AlbumName") or ""}
    except Exception as e:  # noqa: BLE001  (same fallback as library_meta(): the file name)
        labels[f] = {"label": re.sub(r"[_-]+", " ", re.sub(r"(_v[0-9_]+)?(_DD)?(_[mp])?\.psarc$", "", f, flags=re.I)), "album": ""}
# duplicates: album in brackets (as library_choices())
seen = {}
for f, v in labels.items(): seen.setdefault(v["label"], []).append(f)
for lab, fs in seen.items():
    if len(fs) > 1:
        for f in fs:
            if labels[f]["album"]: labels[f]["label"] = "%s (%s)" % (lab, labels[f]["album"])
json.dump(labels, open(os.path.join(OUT, "library.json"), "w"), indent=1, ensure_ascii=False)
print(len(labels), "library entries")

# ---- what the server pushes after a song loads (updateSelectInput): arrangements, sections; + a click track
import subprocess, wave
import numpy as np

def fmt_time(t): return "%d:%02d" % (int(t // 60), int(t % 60))      # format_time() in R/mod_player.R

def arrangements(arc):                                            # list_arrangements(): manifest names, ordered, unique labels
    rows = []
    for m in arc.find(r"^manifests/.*\.json$"):
        a = list(json.loads(arc.read(m))["Entries"].values())[0]["Attributes"]
        if not a.get("ArrangementName") or a["ArrangementName"] in ("Vocals", "JVocals", "ShowLights"): continue
        rows.append((os.path.splitext(os.path.basename(m))[0], a["ArrangementName"]))
    order = {"Lead": 0, "Rhythm": 1, "Combo": 2, "Bass": 3}
    rows.sort(key=lambda r: (order.get(re.sub(r"[0-9]+$", "", r[1]), 9), r[0]))
    names = [r[1] for r in rows]; labels = []
    for i, n in enumerate(names):
        labels.append("%s %d" % (n, names[:i + 1].count(n)) if names.count(n) > 1 else n)
    return [{"id": r[0], "label": l} for r, l in zip(rows, labels)]

songs = {}
for fname, part, tag, diff in CHARTS:
    chart, key, arc = built[tag]
    secs = R.section_labels([dict(s) for s in chart["sections"]])
    arrs = arrangements(arc)
    sel = next((a["id"] for a in arrs if a["id"].endswith("_" + part)), arrs[0]["id"] if arrs else "")
    songs[tag] = {"file": fname, "library_label": labels[fname]["label"], "arrangements": arrs, "arrangement": sel,
                  "sections": ["%s  \u00b7  %s" % (s["label"], fmt_time(s["time"])) for s in secs], "songKey": key}
    # click track at every note onset, as tests/reference/make_fixtures.py makes for the frontend checks
    pay = json.load(open(os.path.join(OUT, "charts", tag + ".json")))
    sr, dur = 22050, float(pay["meta"]["song_length"]) + 1
    x = np.zeros(int(sr * dur), dtype=np.float32)
    click = (np.sin(2 * np.pi * 2000 * np.arange(int(0.004 * sr)) / sr) * np.hanning(int(0.004 * sr))).astype(np.float32)
    for t in sorted(set(pay["notes"]["t"])):
        i = int(round(t * sr))
        if i + len(click) < len(x): x[i:i + len(click)] += 0.5 * click
    wav = os.path.join(OUT, tag + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr); w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    os.makedirs(os.path.join(OUT, "audio"), exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", wav, "-vn", "-c:a", "libvorbis", "-q:a", "5",
                    os.path.join(OUT, "audio", tag + ".ogg")], check=True)
    os.remove(wav)
json.dump(songs, open(os.path.join(OUT, "songs.json"), "w"), indent=1, ensure_ascii=False)
print("songs.json:", {k: (len(v["arrangements"]), len(v["sections"])) for k, v in songs.items()})
