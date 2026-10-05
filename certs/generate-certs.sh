#!/usr/bin/env bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

TARGET="${1:-localhost}"

# Detect if TARGET is an IP address
if echo "$TARGET" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  SAN="IP:${TARGET}"
else
  SAN="DNS:${TARGET}"
fi

if [ "$TARGET" = "localhost" ]; then
  SAN="DNS:localhost,IP:127.0.0.1"
  # On Windows Git Bash, use //CN= to prevent path rewriting
  SUBJ="//CN=localhost\O=BankApp\C=IN"
else
  SUBJ="/CN=${TARGET}/O=BankApp/C=IN"
fi

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${TARGET}.key" \
  -out    "${TARGET}.crt" \
  -subj   "$SUBJ" \
  -addext "subjectAltName=${SAN}"

echo "Generated: ${TARGET}.crt + ${TARGET}.key (valid 365 days, SAN=${SAN})"
echo "Next: set DOMAIN=${TARGET} in your .env.instance2 and run docker compose up --build"
