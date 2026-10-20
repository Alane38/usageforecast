#!/bin/bash
# Fixe la version affichée de l'app et incrémente le numéro de build.
# Usage : scripts/bump-version.sh 1.5.0
# À lancer à chaque mise à jour installée, pour que l'app, le CHANGELOG et le tag git disent la même chose.
set -euo pipefail
cd "$(dirname "$0")/.."

[[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage : $0 MAJEUR.MINEUR.CORRECTIF" >&2; exit 1; }

PLIST=app/Info.plist
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $1" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $((BUILD + 1))" "$PLIST"
echo "Version $1 (build $((BUILD + 1)))"
