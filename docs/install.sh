#!/bin/sh
# Installe (ou met à jour) UsageForecast depuis la dernière release GitHub, après vérification de l'empreinte SHA-256.
#   curl -fsSL https://alane38.github.io/usageforecast/install.sh | sh
# Désinstaller : ajouter  -s -- --uninstall   (les données restent ; ajouter --purge pour les mettre aussi à la Corbeille).
set -eu

REPO="Alane38/usageforecast"
BUNDLE_ID="com.alane.usageforecast"
APP_NAME="UsageForecast.app"
# USAGEFORECAST_DEST : dossier d'installation de remplacement (tests) ; sans quitter ni ouvrir l'app.
DEST="${USAGEFORECAST_DEST:-/Applications/$APP_NAME}"
DATA="$HOME/Library/Application Support/UsageForecast"

say() { printf '%s\n' "$*"; }
die() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }

to_trash() {
    [ -e "$1" ] || return 0
    mv "$1" "$HOME/.Trash/$(basename "$1")-$(date +%s)"
}

quit_app() {
    [ -z "${USAGEFORECAST_DEST:-}" ] || return 0
    pkill -x UsageForecast 2>/dev/null || true
    sleep 1
}

if [ "${1:-}" = "--uninstall" ]; then
    quit_app
    to_trash "$DEST"
    say "UsageForecast est à la Corbeille."
    if [ "${2:-}" = "--purge" ]; then
        to_trash "$DATA"
        say "Données mises à la Corbeille : $DATA"
        say "Le mot de passe enregistré dans le trousseau reste : ouvre « Trousseau d'accès » et cherche $BUNDLE_ID pour le retirer."
    else
        say "Tes données restent dans $DATA (ajoute --purge pour les retirer)."
    fi
    exit 0
fi

[ "$(uname -s)" = "Darwin" ] || die "UsageForecast ne fonctionne que sur macOS."
[ "$(uname -m)" = "arm64" ] || die "La release est compilée pour les Mac Apple Silicon (arm64) uniquement."

work=$(mktemp -d)
trap 'mv "$work" "$HOME/.Trash/usageforecast-install-$$" 2>/dev/null || true' EXIT

say "Recherche de la dernière version…"
api=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest") || die "GitHub est injoignable."
tag=$(printf '%s' "$api" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)
[ -n "$tag" ] || die "Aucune release trouvée."
version=${tag#v}
zip="UsageForecast-$version-arm64.zip"
base="https://github.com/$REPO/releases/download/$tag"

say "Téléchargement de la version $version…"
curl -fsSL -o "$work/$zip" "$base/$zip" || die "Téléchargement impossible : $base/$zip"
curl -fsSL -o "$work/$zip.sha256" "$base/$zip.sha256" || die "Fichier d'empreinte introuvable."

expected=$(awk '{print $1}' "$work/$zip.sha256")
actual=$(shasum -a 256 "$work/$zip" | awk '{print $1}')
[ "$expected" = "$actual" ] || die "Empreinte SHA-256 différente : archive corrompue ou modifiée, rien n'est installé."
say "Empreinte vérifiée."

ditto -x -k "$work/$zip" "$work/out"
found="$work/out/$APP_NAME"
[ -d "$found" ] || die "L'archive ne contient pas $APP_NAME."
id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$found/Contents/Info.plist" 2>/dev/null || true)
[ "$id" = "$BUNDLE_ID" ] || die "Identifiant inattendu dans l'archive ($id)."

quit_app
to_trash "$DEST"
ditto "$found" "$DEST"
say "Installé dans $DEST (version $version)."
[ -n "${USAGEFORECAST_DEST:-}" ] || open "$DEST"
