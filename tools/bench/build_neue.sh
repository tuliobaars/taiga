#!/usr/bin/env bash
# teal_neue / BlockR bench: webR render of the app (neue_driver.R) + site. Usage: bash build_neue.sh teal_neue|BlockR
set -e; APP=$1; HERE="$(cd "$(dirname "$0")" && pwd)"; WS="$(cd "$HERE/../../.." && pwd)"; cd "$HERE"
echo $APP > /tmp/app_$APP.txt; rm -rf /tmp/taiga-bench/$APP
node run_r.mjs neue_driver.R --mount=shim.R:/bench/shim.R --mount=/tmp/app_$APP.txt:/bench/app.txt --mount=blockr_standins.R:/bench/blockr_standins.R --mount=$WS/$APP:/app \
  --mount=$WS/$APP/cache/lumen_adam.rds:/app/cache/lumen_adam.rds --pull=/bench/out:/tmp/taiga-bench/$APP 2>&1 | grep -v -E "^(\[\[|  *\[\[|$|tryCatch|value|eval|source|withVisible|    |\{|\}|\(function)" 
python3 sites.py $( [ $APP = BlockR ] && echo blockr || echo teal_neue ) >/dev/null
