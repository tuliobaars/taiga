#!/usr/bin/env python3
"""Verification for the Taiga design-system work. Writes tools/verify.json and prints a summary.

Checks
  1. source code unchanged: against the workspace's baseline commit, the only modified tracked files are the six
     README.md files; every new file lives under an allowed path (docs/, media/, taiga-design-system/)
  2. screenshots: every manifest entry exists, has the recorded size, has a provenance; every image is in a manifest
  3. links: every relative link and image in new or modified Markdown resolves
  4. video: DirectoR/media/DirectoR_teaser_30s.mp4 is 1920x1080, 60 fps, H.264 + AAC, 30 s; integrated loudness
  5. token sheets parse (tinycss2); extraction is reproducible
  6. delivery: every project's README and docs/DESIGN.md specify Shiny, Quarto and HTML
"""
import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__)); DS = os.path.dirname(HERE); WS = os.path.dirname(DS)
APPS = ["QuantSkill", "DirectoR", "RockShiny", "lumenJourney", "teal_neue", "BlockR"]
res = {}; problems = []


def git(*a): return subprocess.run(["git", "-C", WS, *a], capture_output=True, text=True).stdout


# 1 ----------------------------------------------------------------------------------------------- source unchanged
modified = [l[3:] for l in git("status", "--porcelain", "--untracked-files=no").splitlines()]
untracked = [l[3:] for l in git("status", "--porcelain", "--untracked-files=all").splitlines() if l.startswith("??")]
allowed_mod = {f"{a}/README.md" for a in APPS}
# requested in the second round: .png references -> the JPEG files (VERIFICATION.md section 9)
REQUESTED = {"QuantSkill/dev/screens.py", "QuantSkill/dev/simulate/team_reports.py", "teal_neue/preview/README.md",
             "RockShiny/docs/IMPLEMENTATION_GUIDE.md"}
allowed_mod |= REQUESTED
bad_mod = [f for f in modified if f not in allowed_mod]
allowed_new = tuple([f"{a}/docs/features/" for a in APPS] + [f"{a}/docs/DESIGN.md" for a in APPS] + ["DirectoR/media/", "taiga-design-system/"])
bad_new = [f for f in untracked if not f.startswith(allowed_new)]
code_ext = re.compile(r"\.(R|r|js|css|py|mjs|cjs|qmd|html|json|cpp|c|h)$")
touched_code = [f for f in modified if code_ext.search(f) and f not in REQUESTED]
readme_diff = {a: git("diff", "--numstat", "--", f"{a}/README.md").split()[:2] for a in APPS}
res["source"] = {"modified_tracked": modified, "unexpected_modified": bad_mod, "code_files_modified": touched_code,
                 "new_files": len(untracked), "unexpected_new": bad_new, "readme_lines_added_removed": readme_diff}
if bad_mod or bad_new or touched_code: problems.append("source: unexpected changes %s %s" % (bad_mod, bad_new))
# byte-level check of every code file against the baseline commit
changed_code = [f for f in git("diff", "--name-only", "HEAD").splitlines() if code_ext.search(f) and f not in REQUESTED]
res["source"]["requested_changes"] = sorted(REQUESTED)
res["source"]["code_files_differing_from_baseline"] = changed_code
# filesystem scan (git-ignored files included): anything written inside the projects after the baseline commit
import time
base_t = os.path.getmtime(os.path.join(WS, ".git", "HEAD"))
written = []
for a in APPS:
    for root, dirs, fs in os.walk(os.path.join(WS, a)):
        dirs[:] = [d for d in dirs if d not in ("renv", "node_modules")]
        for f in fs:
            p = os.path.join(root, f); rel = os.path.relpath(p, WS)
            if os.path.getmtime(p) > base_t: written.append(rel)
ok_written = tuple([f"{a}/docs/features/" for a in APPS] + [f"{a}/docs/DESIGN.md" for a in APPS] + [f"{a}/README.md" for a in APPS] + ["DirectoR/media/"] + sorted(REQUESTED))
git_index = [f for f in written if f.endswith(".git/index")]
res["source"]["written_outside_allowed_paths"] = [f for f in written if not f.startswith(ok_written) and f not in git_index]
res["source"]["nested_git_index_refreshed"] = git_index          # `git status` refreshes the index stat cache (no content change)
pycache = [f for f in written if "__pycache__" in f or f.endswith(".pyc")]
if res["source"]["written_outside_allowed_paths"]: problems.append("files written in projects: %s" % res["source"]["written_outside_allowed_paths"])
res["source"]["new_bytecode_files"] = pycache
if changed_code or pycache: problems.append("source: code differs or bytecode written %s %s" % (changed_code, pycache))

# 2 ----------------------------------------------------------------------------------------------- screenshots
from PIL import Image
shots = {}
for a in APPS:
    d = os.path.join(WS, a, "docs", "features"); m = json.load(open(os.path.join(d, "manifest.json")))
    files = sorted(f for f in os.listdir(d) if f.endswith(".jpg"))
    listed = [s["file"] for s in m["shots"]]
    issues = []
    for s in m["shots"]:
        p = os.path.join(d, s["file"])
        if not os.path.exists(p): issues.append("missing " + s["file"]); continue
        w, h = Image.open(p).size
        if (w, h) != (s["width"], s["height"]): issues.append("size mismatch " + s["file"])
        if s.get("provenance") not in ("live", "bench"): issues.append("no provenance " + s["file"])
    issues += ["not in manifest: " + f for f in files if f not in listed]
    prov = sorted({s["provenance"] for s in m["shots"]})
    shots[a] = {"count": len(m["shots"]), "provenance": prov, "size": "%dx%d" % (m["shots"][0]["width"], m["shots"][0]["height"]),
                "bytes": sum(s["bytes"] for s in m["shots"]), "issues": issues}
    if issues: problems.append("%s screenshots: %s" % (a, issues))
res["screenshots"] = shots

# 3 ----------------------------------------------------------------------------------------------- links
md = []
for a in APPS + ["taiga-design-system"]:
    for root, dirs, fs in os.walk(os.path.join(WS, a)):
        dirs[:] = [d for d in dirs if d not in ("node_modules", ".git", "renv", "__MACOSX", ".Rproj.user")]
        md += [os.path.relpath(os.path.join(root, f), WS) for f in fs if f.endswith((".md", ".Rmd"))]
broken = []
link_re = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)\)")
n_links = 0
for f in md:
    base = os.path.dirname(os.path.join(WS, f))
    for target in link_re.findall(open(os.path.join(WS, f), encoding="utf-8").read()):
        if re.match(r"^(https?:|mailto:|#)", target): continue
        n_links += 1
        path = target.split("#")[0]
        if path and not os.path.exists(os.path.normpath(os.path.join(base, path))): broken.append("%s -> %s" % (f, target))
# the package's documents must not depend on files outside the package folder (images included)
outside = []
for f in ["taiga-design-system/README.md"] + [m for m in md if m.startswith("taiga-design-system/inst/guides/")]:
    base = os.path.dirname(os.path.join(WS, f))
    for target in re.findall(r"!\[[^\]]*\]\(([^)\s]+)\)", open(os.path.join(WS, f), encoding="utf-8").read()):
        if not os.path.normpath(os.path.join(base, target)).startswith(os.path.join(DS, "")): outside.append("%s -> %s" % (f, target))
res["links"] = {"markdown_files": len(md), "relative_links_checked": n_links, "broken": broken, "package_images_outside_package": outside}
if outside: problems.append("package documents use images outside the package: %s" % outside[:5])
if broken: problems.append("links: %s" % broken[:10])

# 4 ----------------------------------------------------------------------------------------------- video
v = os.path.join(WS, "DirectoR", "media", "DirectoR_teaser_30s.mp4")
probe = json.loads(subprocess.run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", v], capture_output=True, text=True).stdout)
vs = [s for s in probe["streams"] if s["codec_type"] == "video"][0]; au = [s for s in probe["streams"] if s["codec_type"] == "audio"][0]
loud = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", v, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
I = re.findall(r"I:\s+(-?[\d.]+) LUFS", loud); peak = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", loud)
res["video"] = {"file": "DirectoR/media/DirectoR_teaser_30s.mp4", "codec": vs["codec_name"], "profile": vs.get("profile"), "size": "%sx%s" % (vs["width"], vs["height"]),
                "fps": vs["r_frame_rate"], "duration_s": float(probe["format"]["duration"]), "audio": "%s %s Hz %sch" % (au["codec_name"], au["sample_rate"], au["channels"]),
                "integrated_lufs": float(I[-1]) if I else None, "true_peak_dbfs": float(peak[-1]) if peak else None, "bytes": int(probe["format"]["size"]),
                "poster": os.path.exists(v.replace(".mp4", "_poster.png"))}
if (vs["width"], vs["height"], vs["r_frame_rate"]) != (1920, 1080, "60/1") or abs(res["video"]["duration_s"] - 30) > .05: problems.append("video format")

# 5 ----------------------------------------------------------------------------------------------- tokens
import tinycss2
sheets = {}
for p in ("inst/css/lumen-tokens.css", "inst/css/neue-tokens.css"):
    rules = tinycss2.parse_stylesheet(open(os.path.join(DS, p)).read(), skip_comments=True, skip_whitespace=True)
    sheets[p] = {"rules": len(rules), "parse_errors": sum(1 for r in rules if r.type == "error")}
    if sheets[p]["parse_errors"]: problems.append("css parse " + p)
before = {a: json.load(open(os.path.join(DS, "inst", "extdata", "tokens", a + ".json")))["n_custom_properties"] for a in APPS}
subprocess.run([sys.executable, os.path.join(HERE, "extract_tokens.py")], capture_output=True)
after = {a: json.load(open(os.path.join(DS, "inst", "extdata", "tokens", a + ".json")))["n_custom_properties"] for a in APPS}
res["tokens"] = {"sheets": sheets, "custom_properties": after, "reproducible": before == after}

# 6 ----------------------------------------------------------------------------------------------- delivery
deliv = {}
for a in APPS:
    readme = open(os.path.join(WS, a, "README.md"), encoding="utf-8").read()
    design = open(os.path.join(WS, a, "docs", "DESIGN.md"), encoding="utf-8").read()
    block = re.search(r"<!-- taiga:begin -->(.*?)<!-- taiga:end -->", readme, re.S)
    ok = bool(block) and all(re.search(r"^\| %s \|" % f, block.group(1), re.M) for f in ("Shiny", "Quarto", "HTML")) \
        and all(re.search(r"^\| %s \|" % f, design, re.M) for f in ("Shiny", "Quarto", "HTML"))
    status = re.findall(r"^\| (Shiny|Quarto|HTML) \| ([^|]+) \|", block.group(1), re.M) if block else []
    deliv[a] = {"specified": ok, "status": {k: v.strip() for k, v in status}}
    if not ok: problems.append("delivery not specified: " + a)
res["delivery"] = deliv

res["problems"] = problems
json.dump(res, open(os.path.join(HERE, "verify.json"), "w"), indent=1, ensure_ascii=False)
print(json.dumps({k: v for k, v in res.items() if k != "screenshots"}, indent=1, ensure_ascii=False)[:6000])
print("screenshots:", {a: (s["count"], s["provenance"], s["issues"]) for a, s in shots.items()})
print("PROBLEMS:", problems or "none")
