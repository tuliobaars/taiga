#!/usr/bin/env bash
# Build the DirectoR bench end to end (nothing inside /workspace/DirectoR is written):
#   1. real DirectoR engine projects (python -m director scout/plan/capture/timeline) in $DR_HOME,
#      from QuantSkill's and lumenJourney's standalone HTML builds (+ a screenshots-and-recordings film of BlockR)
#   2. DirectoR's R UI + renderUI outputs rendered in webR (shim.R) -> /tmp/taiga-bench/director
#   3. the bench site -> /tmp/taiga-bench/sites/director
# Usage: bash build_director.sh [--skip-engine]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; WS="$(cd "$HERE/../../.." && pwd)"
DR_HOME=/tmp/taiga-dr/home; CODE="$HOME/code"
engine() { PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$WS/DirectoR/inst/engine" DIRECTOR_HOME="$DR_HOME" python3 -m director "$@"; }

if [[ "${1:-}" != "--skip-engine" ]]; then
  rm -rf "$DR_HOME" && mkdir -p "$DR_HOME/projects" "$CODE/quantskill" "$CODE/lumen-story" "$CODE/blockr-shots"
  # sources: the apps' own standalone builds + READMEs (the scout reads the README to write the copy)
  cp "$WS/QuantSkill/inst/html/quantskill.html" "$CODE/quantskill/index.html"; cp "$WS/QuantSkill/README.md" "$CODE/quantskill/"
  (cd "$WS/lumenJourney" && node tools/story-dev/build.mjs "$CODE/lumen-story/index.html" >/dev/null); cp "$WS/lumenJourney/README.md" "$CODE/lumen-story/"
  mk() {  # slug name kind value template created
    mkdir -p "$DR_HOME/projects/$1"
    printf '{"name": "%s", "name_auto": false, "created": "%s", "source": {"kind": "%s", "value": "%s"}, "film": {"template": "%s"}, "format": {"aspect": "16:9"}, "capture": {"fps": 30, "dpr": 1, "lite": "true", "workers": 3}}\n' \
      "$2" "$6" "$3" "$4" "$5" > "$DR_HOME/projects/$1/project.json"
  }
  mk quantskill "QuantSkill" dir "~/code/quantskill" launch 2026-11-11T18:00:00
  mk lumen-story "Lumen study story" dir "~/code/lumen-story" teaser 2026-11-11T18:05:00
  for p in quantskill lumen-story; do
    engine scout -p "$DR_HOME/projects/$p"; engine plan -p "$DR_HOME/projects/$p" --no-llm; engine capture -p "$DR_HOME/projects/$p"; engine timeline -p "$DR_HOME/projects/$p"
  done
  # a "screenshots & recordings" film: DirectoR's media source, fed with BlockR's bench screenshots (if captured already)
  if ls "$WS"/BlockR/docs/features/*.jpg >/dev/null 2>&1; then
    mk blockr "BlockR" media "" tour 2026-11-11T18:10:00
    mkdir -p "$DR_HOME/projects/blockr/media"; items=""
    # labels: the screenshot titles from BlockR/docs/features/manifest.json
    python3 - "$WS" "$DR_HOME" <<'PY'
import json, shutil, sys, os
ws, home = sys.argv[1], sys.argv[2]
man = json.load(open(os.path.join(ws, "BlockR/docs/features/manifest.json")))["shots"]
items = []
for s in man[:6]:
    shutil.copy(os.path.join(ws, "BlockR/docs/features", s["file"]), os.path.join(home, "projects/blockr/media", s["file"]))
    items.append({"file": "media/" + s["file"], "label": s["title"]})
json.dump({"items": items}, open(os.path.join(home, "projects/blockr/media.json"), "w"), indent=1)
PY
    engine plan -p "$DR_HOME/projects/blockr" --no-llm; engine capture -p "$DR_HOME/projects/blockr"; engine timeline -p "$DR_HOME/projects/blockr"
    engine render -p "$DR_HOME/projects/blockr" --quality draft
  fi
  engine render -p "$DR_HOME/projects/quantskill" --quality draft      # a real render: poster on the Library card, a render card in Export
  engine doctor --json > "$DR_HOME/doctor.json"
fi

rm -rf /tmp/taiga-bench/director
(cd "$HERE" && node run_r.mjs director_driver.R --mount=shim.R:/bench/shim.R --mount="$WS/DirectoR":/app \
   --mount="$DR_HOME":"$DR_HOME" --pull=/bench/out:/tmp/taiga-bench/director)
(cd "$HERE" && python3 sites.py director)
