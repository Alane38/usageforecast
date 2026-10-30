#!/bin/bash
# Régression visuelle : rend les écrans de démonstration de l'app compilée et les compare aux références de tests/visual/ref.
# Usage : scripts/visual-check.sh            compare (code 1 au premier écart, images dans build/visual/diff)
#         scripts/visual-check.sh --update   remplace les références par le rendu actuel (après un changement voulu)
# Local seulement : le rendu dépend des polices et de la version de macOS, donc pas dans la CI.
# Les captures de démonstration sont ancrées sur minuit : seuls le nom du dernier jour du planning et le décompte « reset dans »
# varient avec le jour et l'heure, d'où la tolérance de 0,1 % de pixels.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/UsageForecast.app/Contents/MacOS/UsageForecast
[ -x "$APP" ] || { echo "Compile d'abord : scripts/build.sh" >&2; exit 1; }

SDK_ROOT=/Library/Developer/CommandLineTools/SDKs
SDK="${CUB_SDK:-$SDK_ROOT/MacOSX26.5.sdk}"
[ -d "$SDK" ] || SDK="$SDK_ROOT/MacOSX26.sdk"
mkdir -p build/visual/actual build/visual/diff tests/visual/ref
swiftc -sdk "$SDK" -o build/visual-diff scripts/visual-diff.swift

# nom : arguments de l'app
SCENES=(
  "jauges-sombre:--layout gauges --open-history"
  "jauges-clair:--layout gauges --open-history --light"
  "cartes-sombre:--layout cards"
  "cartes-clair:--layout cards --light"
  "cartes-limite-sombre:--layout cards --session 87 --weekly 82"
  "cartes-limite-clair:--layout cards --session 87 --weekly 82 --light"
  "budget-jour-ok:--layout gauges --used-today 9"
  "budget-jour-proche-clair:--layout gauges --used-today 21 --light"
  "budget-jour-depasse:--layout cards --used-today 31"
  "planning-ok:--layout gauges --used-today 9 --open-plan"
  "planning-depasse:--layout gauges --used-today 40 --open-plan"
  "planning-clair:--layout gauges --used-today 21 --open-plan --light"
  "planning-debut-de-semaine:--layout gauges --weekly 1 --used-today 1 --weekly-left 424800 --open-plan"
  "planning-fin-de-semaine:--layout gauges --weekly 20 --used-today 13 --weekly-left 525600 --open-plan"
  "stats-sombre:--settings --tab stats --height 1250"
  "stats-clair-mercredi:--settings --tab stats --height 1250 --light --demo-day-shift 3"
  "stats-peu-de-donnees:--settings --tab stats --height 1250 --demo-days 2"
  "stats-journal:--settings --tab stats --height 1500 --open-journal"
  "mobile-sombre:--settings --tab mobile --height 760 --demo-mobile"
  "mobile-code-clair:--settings --tab mobile --height 1250 --demo-mobile --show-code --light"
  "mise-a-jour:--layout cards --demo-update"
  "mise-a-jour-echec:--layout cards --demo-update failed"
  "bienvenue:--welcome"
  "barre-de-menu:--menubar-styles"
  "reglages-affichage:--settings --tab display"
)

failed=0
for scene in "${SCENES[@]}"; do
    name="${scene%%:*}"
    # shellcheck disable=SC2086
    "$APP" --no-keychain --demo --snapshot "build/visual/actual/$name.png" ${scene#*:} >/dev/null 2>&1
    if [ "${1:-}" = "--update" ]; then
        cp "build/visual/actual/$name.png" "tests/visual/ref/$name.png"
        echo "référence mise à jour : $name"
    elif [ ! -f "tests/visual/ref/$name.png" ]; then
        echo "SANS RÉFÉRENCE : $name (lance --update)"; failed=1
    elif result=$(build/visual-diff "tests/visual/ref/$name.png" "build/visual/actual/$name.png" "build/visual/diff/$name.png"); then
        echo "ok   $name : $result"
    else
        echo "ÉCART $name : $result → build/visual/diff/$name.png"; failed=1
    fi
done
exit $failed
