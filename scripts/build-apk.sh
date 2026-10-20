#!/bin/bash
# APK Android (coque WebView de la PWA) : build/UsageForecast-<version>-android.apk.
# Signé avec la clé de debug Android (~/.android/debug.keystore, ou UF_KEYSTORE) : voir android/README.md.
# Prérequis : JDK 17 et SDK Android (ANDROID_HOME, par défaut ~/Library/Android/sdk) avec les licences
# déjà acceptées par l'utilisateur ; ce script n'en accepte aucune.
set -euo pipefail

cd "$(dirname "$0")/.."

PLIST=app/Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
SIGNING_STORE="${UF_KEYSTORE:-$HOME/.android/debug.keystore}"

[ -d "$ANDROID_HOME/platforms" ] || { echo "SDK Android introuvable dans $ANDROID_HOME" >&2; exit 1; }
[ -f "$SIGNING_STORE" ] || { echo "Clé de signature introuvable : $SIGNING_STORE (lance une fois un build Android Studio ou keytool, voir android/README.md)" >&2; exit 1; }
[ -s "$ANDROID_HOME/licenses/android-sdk-license" ] || {
    echo "Licences du SDK Android non acceptées : à faire par toi (sdkmanager --licenses), puis relance." >&2
    exit 1
}

./android/gradlew -p android -PappVersion="$VERSION" -PappBuild="$BUILD" :app:testReleaseUnitTest :app:assembleRelease

APK_BUILT=android/app/build/outputs/apk/release/app-release.apk
APK_OUT="build/UsageForecast-$VERSION-android.apk"
mkdir -p build
cp "$APK_BUILT" "$APK_OUT"

APKSIGNER=$(ls -d "$ANDROID_HOME"/build-tools/*/apksigner | sort -V | tail -1)
"$APKSIGNER" verify --print-certs "$APK_OUT" | sed -n '1,3p'
echo "APK prêt : $APK_OUT ($(du -h "$APK_OUT" | cut -f1))"
