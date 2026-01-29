#!/usr/bin/env bash
# Setup stable development code signing to reduce keychain prompts.
set -euo pipefail

APP_NAME=${APP_NAME:-BuienBar}
CERT_NAME="${APP_NAME} Development"

if security find-identity -p codesigning -c "$CERT_NAME" >/dev/null 2>&1; then
  echo "Refreshing existing identity '$CERT_NAME'..."
  security delete-identity -c "$CERT_NAME" ~/Library/Keychains/login.keychain-db >/dev/null 2>&1 || true
fi

echo "Creating self-signed certificate '$CERT_NAME'..."

TEMP_CONFIG=$(mktemp)
trap "rm -f $TEMP_CONFIG" EXIT

cat > "$TEMP_CONFIG" <<EOFCONF
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = $CERT_NAME
O = ${APP_NAME} Development
C = US

[ v3_req ]
keyUsage = critical,digitalSignature
extendedKeyUsage = codeSigning
EOFCONF

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 \
    -nodes -keyout /tmp/dev.key -out /tmp/dev.crt \
    -config "$TEMP_CONFIG" 2>/dev/null

DEV_P12_PASS="buienbar"

openssl pkcs12 -legacy -export -out /tmp/dev.p12 \
    -inkey /tmp/dev.key -in /tmp/dev.crt \
    -passout pass:${DEV_P12_PASS} 2>/dev/null

security import /tmp/dev.p12 -k ~/Library/Keychains/login.keychain-db \
  -P "${DEV_P12_PASS}" -A


rm -f /tmp/dev.{key,crt,p12}

echo ""
echo "Trust this certificate for code signing in Keychain Access."
echo "Then export in your shell profile:"
echo "  export APP_IDENTITY='$CERT_NAME'"
