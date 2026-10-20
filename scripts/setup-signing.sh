#!/bin/bash
# Crée une seule fois un certificat de signature local, pour que l'identité de l'app reste la même
# d'un build à l'autre. Avec une signature ad-hoc, chaque build change d'identité et macOS redemande
# l'accès au Keychain, à l'Accessibilité et aux notifications.
# Le certificat reste dans ton trousseau « session » et ne sert qu'à signer ce projet.
set -euo pipefail

NAME="UsageForecast Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning | grep -q "$NAME"; then
    echo "Certificat « $NAME » déjà présent."
    exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$WORK/cert.cnf" \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null

PASSWORD=$(/usr/bin/openssl rand -hex 16)
/usr/bin/openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -out "$WORK/identity.p12" -passout "pass:$PASSWORD"
security import "$WORK/identity.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign

# Une fenêtre macOS demande le mot de passe de la session : c'est la seule étape manuelle.
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem"

echo "OK : certificat « $NAME » créé et approuvé pour la signature de code."
