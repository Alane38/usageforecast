#!/bin/bash
# Régénère les captures du README et du site (docs/img) depuis les écrans de démonstration : données fictives uniquement.
# Usage : scripts/make-screenshots.sh   (compile d'abord avec scripts/build.sh)
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/UsageForecast.app/Contents/MacOS/UsageForecast
[ -x "$APP" ] || { echo "Compile d'abord : scripts/build.sh" >&2; exit 1; }
mkdir -p docs/img

# nom : arguments de l'app
SHOTS=(
  "popover-sombre:--layout gauges --open-history"
  "popover-clair:--layout cards --light"
  "previsions:--layout gauges --used-today 9 --open-plan"
  "statistiques:--settings --tab stats --height 1250"
  "barre-de-menu:--menubar-styles"
)
for shot in "${SHOTS[@]}"; do
    name="${shot%%:*}"
    # shellcheck disable=SC2086
    "$APP" --no-keychain --demo --snapshot "docs/img/$name.png" ${shot#*:} >/dev/null 2>&1
    echo "docs/img/$name.png"
done
