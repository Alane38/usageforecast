#!/bin/bash
# Fixe la version de l'APK Android et incrémente son numéro de build (android/version.properties).
# Usage : scripts/bump-android.sh 1.19.1   (ne touche pas à la version de l'application Mac)
set -euo pipefail
cd "$(dirname "$0")/.."

[[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage : $0 MAJEUR.MINEUR.CORRECTIF" >&2; exit 1; }
BUILD=$(sed -n 's/^versionCode=//p' android/version.properties)
sed -i '' "s/^versionName=.*/versionName=$1/; s/^versionCode=.*/versionCode=$((BUILD + 1))/" android/version.properties
echo "APK Android $1 (build $((BUILD + 1)))"
