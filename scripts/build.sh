#!/bin/bash
# Build local sans Xcode.app ni certificat Developer ID : Command Line Tools + signature ad-hoc.
# Pourquoi le SDK 26 : avec le SDK 27, @State devient une macro (plugin SwiftUIMacros)
# qui n'est livrée qu'avec Xcode.app.
set -euo pipefail

# Développement (défaut) : cookies dans un fichier protégé, aucune fenêtre du trousseau.
# `--release` : cookies dans le trousseau macOS (chiffré). Voir docs/adr/001-stockage-des-secrets.md.
MODE_FLAGS=()
MODE_LABEL="développement (secrets dans un fichier)"
if [ "${1:-}" = "--release" ]; then
    MODE_FLAGS=(-D RELEASE)
    MODE_LABEL="release (secrets dans le trousseau)"
fi

cd "$(dirname "$0")/.."
SDK_ROOT=/Library/Developer/CommandLineTools/SDKs
SDK="${CUB_SDK:-$SDK_ROOT/MacOSX26.5.sdk}"
[ -d "$SDK" ] || SDK="$SDK_ROOT/MacOSX26.sdk"
[ -d "$SDK" ] || { echo "SDK 26 introuvable dans $SDK_ROOT" >&2; exit 1; }

APP=build/UsageForecast.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp app/Info.plist "$APP/Contents/"
cp app/UsageForecast.icns "$APP/Contents/Resources/"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

swiftc -parse-as-library ${MODE_FLAGS[@]+"${MODE_FLAGS[@]}"} -sdk "$SDK" -target arm64-apple-macos13.0 \
    -o "$APP/Contents/MacOS/UsageForecast" app/*.swift \
    -framework SwiftUI -framework AppKit -framework WebKit -framework UserNotifications

xattr -cr "$APP"
# Identité stable : même règle de signature à chaque build, donc macOS garde les autorisations
# (Keychain, Accessibilité, notifications). Sans certificat local, repli ad-hoc : elles seront redemandées.
# Certificat local (scripts/setup-signing.sh) ; UF_SIGNING_IDENTITY permet d'en utiliser un autre.
IDENTITY="${UF_SIGNING_IDENTITY:-UsageForecast Local Signing}"
if security find-identity -p codesigning | grep -q "$IDENTITY"; then
    codesign --force --deep --sign "$IDENTITY" "$APP"
else
    echo "Pas de certificat local (scripts/setup-signing.sh) : signature ad-hoc, les permissions seront redemandées." >&2
    codesign --force --deep --sign - "$APP"
fi
codesign --verify --verbose=2 "$APP"
echo "OK : $APP — mode $MODE_LABEL"
