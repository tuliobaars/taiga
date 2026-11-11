#!/usr/bin/env bash
# Check the taiga package in webR (see tools/check_webr.R). Needs `npm install` in tools/bench.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; PKG="$(dirname "$HERE")"; WS="$(dirname "$PKG")"
python3 "$HERE/document.py"
cd "$HERE/bench" && node run_r.mjs "$HERE/check_webr.R" --mount="$HERE/bench/shim.R":/bench/shim.R \
  --mount="$WS/QuantSkill/dev/tests/testthat_shim.R":/qs/testthat_shim.R \
  --mount="$PKG/DESCRIPTION":/pkg/DESCRIPTION --mount="$PKG/NAMESPACE":/pkg/NAMESPACE --mount="$PKG/R":/pkg/R \
  --mount="$PKG/man":/pkg/man --mount="$PKG/inst":/pkg/inst --mount="$PKG/inst/examples":/pkg/inst/examples --mount="$PKG/tests":/pkg/tests --mount="$PKG/vignettes":/pkg/vignettes
