#!/usr/bin/env bash
# RockShiny bench: charts + labels (RockShiny's Python reference implementation), webR render of app.R's ui(), site.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; WS="$(cd "$HERE/../../.." && pwd)"; cd "$HERE"
PYTHONDONTWRITEBYTECODE=1 python3 rockshiny_fixtures.py
rm -rf /tmp/taiga-bench/rockshiny/ui
node run_r.mjs rockshiny_driver.R --mount=shim.R:/bench/shim.R --mount=/tmp/taiga-bench/rockshiny/library.json:/bench/library.json \
  --mount="$WS/RockShiny":/app --pull=/bench/out:/tmp/taiga-bench/rockshiny/ui
python3 sites.py rockshiny
