#!/bin/bash
# Build de release : secrets dans le trousseau macOS. À lancer quand on déploie, pas pendant le développement.
exec "$(dirname "$0")/build.sh" --release
