#!/usr/bin/env bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

# On Windows Git Bash, use //CN= to prevent path rewriting
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout localhost.key \
  -out    localhost.crt \
  -subj   "//CN=localhost\O=BankApp\C=IN" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

echo "Generated: localhost.crt + localhost.key (valid 365 days)"
echo "Next: docker compose up --build"
