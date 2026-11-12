#!/usr/bin/env bash
# Check the taiga package. Run from anywhere:   bash tools/check.sh [--document] [--webr]
#   (from R, with the package folder as working directory:  system("bash tools/check.sh"))
#
# * With R installed (the normal case): `R CMD build` + `R CMD check --no-manual` in a temporary folder.
#   Needs the Imports (htmltools, jsonlite); Suggests that are missing are skipped, not fatal
#   (knitr/rmarkdown/pandoc missing -> vignettes are not built; testthat missing -> tests are not run).
# * Without R (or with --webr): the webR fallback, tools/check_webr.R, in base R compiled to WebAssembly.
#   Needs Node.js >= 18 and npm; `npm install` is run in tools/bench on first use.
# * The check never edits the package. man/ and NAMESPACE are committed (made by roxygen2); --document
#   regenerates them first, with roxygen2::roxygenise() if installed, else with tools/document.py.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PKG="$(dirname "$HERE")"
DOCUMENT=0; WEBR=0
for a in "$@"; do case "$a" in
  --document|--roxygen) DOCUMENT=1 ;; --webr) WEBR=1 ;;
  -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
  *) echo "check.sh: unknown option $a" >&2; exit 2 ;;
esac; done
cd "$PKG"
have() { command -v "$1" >/dev/null 2>&1; }
if ! have Rscript; then WEBR=1; fi

# --- preflight: is this copy of the package complete? ---------------------------------------------
echo "== package files"
PRE_FAIL=0
for f in DESCRIPTION NAMESPACE R man inst/guides inst/guides/img/thumb inst/guides/img/full inst/css inst/extdata/tokens \
         inst/examples/hello vignettes/taiga.Rmd tests/testthat; do
  [ -e "$f" ] || { echo "   MISSING: $f" >&2; PRE_FAIL=1; }
done
# every picture the guides link to must be in inst/guides/img (they are part of the package)
MISSING_IMG=0; N_IMG=0
while IFS= read -r line; do
  md="${line%%|*}"; ref="${line#*|}"; N_IMG=$((N_IMG + 1))
  [ -f "$(dirname "$md")/$ref" ] || { MISSING_IMG=$((MISSING_IMG + 1)); [ "$MISSING_IMG" -le 3 ] && echo "   MISSING: $(dirname "$md")/$ref" >&2; }
done < <(for md in inst/guides/*.md inst/guides/*/*.md; do
           { grep -oE '\]\([^)#]+\.(jpg|png)\)' "$md" || true; } | sed -E 's/^\]\(//; s/\)$//' | sed "s#^#$md|#"
         done)
if [ "$MISSING_IMG" -gt 0 ]; then
  echo "   $MISSING_IMG of the $N_IMG pictures linked from inst/guides/*.md are missing from this copy of the package." >&2
  echo "   inst/guides/img/ ($(find inst/guides/img -type f 2>/dev/null | wc -l | tr -d ' ') files here) must be copied along with the rest of the folder." >&2
  PRE_FAIL=1
fi
# files dated in the future (e.g. unzipped in a time zone behind the one they were zipped in) make R CMD build
# delete the vignette source: buildVignettes() removes every file newer than the build's start as "intermediate"
NOW="$(mktemp "${TMPDIR:-/tmp}/taiga-now.XXXXXX")"; sleep 1
FUTURE="$(find . -type f -newer "$NOW" -not -path './tools/bench/node_modules/*' | wc -l | tr -d ' ')"
if [ "$FUTURE" -gt 0 ]; then
  echo "   $FUTURE files have modification times in the future (e.g. $(find . -type f -newer "$NOW" -not -path './tools/bench/node_modules/*' | head -1))."
  echo "   R CMD build would delete vignettes/taiga.Rmd. Setting their times to now (only the times change)."
  find . -type f -newer "$NOW" -not -path './tools/bench/node_modules/*' -exec touch {} +
fi
rm -f "$NOW"
# .Rbuildignore must not drop what the package needs (R CMD build deletes matches after building the vignette)
if [ -f .Rbuildignore ]; then
  while IFS= read -r pat || [ -n "$pat" ]; do
    [ -z "${pat//[[:space:]]/}" ] && continue
    for f in inst/doc/taiga.html vignettes/taiga.Rmd R/delivery.R inst/guides/img/full/format-qs-html.jpg inst/css/lumen-tokens.css; do
      if printf '%s\n' "$f" | grep -qiE -- "$pat" 2>/dev/null; then
        echo "   .Rbuildignore line '$pat' would make R CMD build drop $f: remove that line." >&2; PRE_FAIL=1
      fi
    done
  done < .Rbuildignore
else
  echo "   MISSING: .Rbuildignore (a hidden file; copy it too)" >&2; PRE_FAIL=1
fi
[ "$PRE_FAIL" = 0 ] && echo "   complete ($N_IMG picture links, $(find inst/guides/img -type f | wc -l | tr -d ' ') picture files)"
[ "$PRE_FAIL" = 0 ] || { echo "Stopped: fix the problems above (a complete copy of the taiga-design-system folder has none)." >&2; exit 1; }

if [ "$DOCUMENT" = 1 ]; then
  echo "== documentation (man/, NAMESPACE)"
  if have Rscript && Rscript -e 'q(status = !requireNamespace("roxygen2", quietly = TRUE))' >/dev/null 2>&1; then
    Rscript -e 'roxygen2::roxygenise()'
  elif have python3; then
    PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/document.py"
  else
    echo "--document needs roxygen2 (in R) or python3" >&2; exit 2
  fi
fi

if [ "$WEBR" = 0 ]; then
  echo "== R CMD build / check ($(R --version | head -1))"
  MISSING="$(Rscript -e 'cat(Filter(function(p) !requireNamespace(p, quietly = TRUE), c("htmltools", "jsonlite")))')"
  if [ -n "$MISSING" ]; then
    echo "Missing required packages: $MISSING" >&2
    echo "Install them in R:  install.packages(c($(echo "$MISSING" | sed 's/\([^ ][^ ]*\)/"\1"/g; s/ /, /g')))" >&2
    exit 1
  fi
  BUILD_OPTS=(); CHECK_OPTS=(--no-manual)
  if ! Rscript -e 'q(status = !(requireNamespace("knitr", quietly = TRUE) && requireNamespace("rmarkdown", quietly = TRUE) && rmarkdown::pandoc_available()))' >/dev/null 2>&1; then
    echo "   knitr/rmarkdown/pandoc not available: vignettes are not built"
    BUILD_OPTS+=(--no-build-vignettes); CHECK_OPTS+=(--ignore-vignettes)
  fi
  if ! Rscript -e 'q(status = !requireNamespace("testthat", quietly = TRUE))' >/dev/null 2>&1; then
    echo "   testthat not installed: tests are not run (install.packages(\"testthat\"))"
    CHECK_OPTS+=(--no-tests)
  fi
  OUT="$(mktemp -d "${TMPDIR:-/tmp}/taiga-check.XXXXXX")"
  ( cd "$OUT" && R CMD build ${BUILD_OPTS[@]+"${BUILD_OPTS[@]}"} "$PKG" )
  TARBALL="$(ls "$OUT"/taiga_*.tar.gz)"
  # the tarball must hold what the check needs; if not, say which file went missing and why
  Rscript "$HERE/check_tarball.R" "$TARBALL" "$PKG" ${BUILD_OPTS[@]+"${BUILD_OPTS[@]}"} || exit 1
  set +e
  ( cd "$OUT" && _R_CHECK_FORCE_SUGGESTS_=false R CMD check "${CHECK_OPTS[@]}" "$TARBALL" )
  RC=$?
  set -e
  LOG="$OUT/taiga.Rcheck/00check.log"
  STATUS="$(grep -E '^Status:' "$LOG" 2>/dev/null | tail -1 || true)"
  echo; echo "Log: $LOG"; echo "${STATUS:-Status: unknown}"
  if [ "$RC" != 0 ] || echo "$STATUS" | grep -qE 'ERROR|WARNING'; then exit 1; fi
  exit 0
fi

echo "== webR fallback (no R installation used)"
have node || { echo "Node.js (>= 18) is needed for the webR fallback: https://nodejs.org (or install R and rerun)" >&2; exit 1; }
if [ ! -d "$HERE/bench/node_modules/webr" ]; then
  have npm || { echo "npm is needed to install webR into tools/bench" >&2; exit 1; }
  echo "   installing webR into tools/bench/node_modules (first run only)"
  ( cd "$HERE/bench" && npm install --no-audit --no-fund --loglevel=error )
fi
cd "$HERE/bench"
exec node run_r.mjs "$HERE/check_webr.R" \
  --mount="$HERE/bench/shim.R":/bench/shim.R --mount="$HERE/testthat_shim.R":/bench/testthat_shim.R \
  --mount="$PKG/DESCRIPTION":/pkg/DESCRIPTION --mount="$PKG/NAMESPACE":/pkg/NAMESPACE --mount="$PKG/R":/pkg/R \
  --mount="$PKG/man":/pkg/man --mount="$PKG/inst":/pkg/inst --mount="$PKG/inst/examples":/pkg/inst/examples \
  --mount="$PKG/tests":/pkg/tests --mount="$PKG/vignettes":/pkg/vignettes
