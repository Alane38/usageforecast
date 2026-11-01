#!/bin/bash
# Version du collecteur (canal à part, tags collector-vX.Y.Z) : change VERSION dans mobile/collector/collector.js.
# Usage : scripts/bump-collector.sh X.Y.Z
# Ensuite : section « ## X.Y.Z » dans mobile/collector/CHANGELOG.md, commit, push, puis
#   git tag -a collector-vX.Y.Z -m "Collecteur X.Y.Z" && git push origin collector-vX.Y.Z
# Le workflow release-collector.yml teste, compile les 5 exécutables et publie la release.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Usage : $0 X.Y.Z" >&2; exit 1; }
FILE=mobile/collector/collector.js
grep -q '^export const VERSION = "' "$FILE" || { echo "Ligne VERSION introuvable dans $FILE" >&2; exit 1; }
sed -i.bak "s/^export const VERSION = \".*\";$/export const VERSION = \"$VERSION\";/" "$FILE"   # -i.bak : même syntaxe sous macOS et Linux
if command -v trash >/dev/null; then trash "$FILE.bak"; else rm -f "$FILE.bak"; fi
echo "Collecteur : version $VERSION ($FILE)."
grep -q "^## $VERSION" mobile/collector/CHANGELOG.md || echo "Pense à la section « ## $VERSION » dans mobile/collector/CHANGELOG.md : la release l'exige."
