#!/bin/bash
# Publie l'APK Android dans sa propre release GitHub `android-vX.Y.Z` : l'application Mac, qui ne lit que les tags `vX.Y.Z`,
# ne propose alors aucune mise à jour. Construit et teste l'APK, calcule son SHA-256, puis crée la release.
# Usage : scripts/release-android.sh [fichier-de-notes.md]   (version lue dans android/version.properties)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(sed -n 's/^versionName=//p' android/version.properties)
TAG="android-v$VERSION"
NOTES="${1:-}"
git diff --quiet && git diff --cached --quiet || { echo "Commite d'abord : l'APK doit correspondre à un commit poussé." >&2; exit 1; }
[ "$(git rev-parse HEAD)" = "$(git rev-parse '@{upstream}')" ] || { echo "Pousse d'abord le commit courant (git push)." >&2; exit 1; }

./scripts/build-apk.sh
APK="build/UsageForecast-$VERSION-android.apk"
( cd build && shasum -a 256 "UsageForecast-$VERSION-android.apk" > "UsageForecast-$VERSION-android.apk.sha256" )

if [ -n "$NOTES" ]; then
    gh release create "$TAG" "$APK" "$APK.sha256" --title "UsageForecast Android $VERSION" --notes-file "$NOTES" --target "$(git rev-parse HEAD)"
else
    gh release create "$TAG" "$APK" "$APK.sha256" --title "UsageForecast Android $VERSION" --notes "APK Android $VERSION. Voir CHANGELOG.md." --target "$(git rev-parse HEAD)"
fi
echo "Publié : $TAG"
