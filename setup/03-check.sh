#!/usr/bin/env bash
# setup/03-check.sh
#
# Verify that Traefik and the site are running correctly.
# Checks container health, HTTP→HTTPS redirect, bare→www redirect, and TLS cert.
#
# Usage:
#   bash setup/03-check.sh [DOMAIN]
#
# Arguments:
#   DOMAIN   Domain to check (default: www.revistapelo.com.ar)

set -euo pipefail

DOMAIN="${1:-www.revistapelo.com.ar}"
BARE="${DOMAIN#www.}"

PASS="[ OK ]"
FAIL="[FAIL]"
errors=0

check() {
  local label="$1"
  local result="$2"
  local expected="$3"
  if [[ "$result" == *"$expected"* ]]; then
    echo "$PASS $label"
  else
    echo "$FAIL $label (got: $result)"
    errors=$((errors + 1))
  fi
}

# --- Containers ---
echo "==> Container status"
for name in traefik revista-pelo-web-1 revista-pelo_web_1; do
  if docker ps --format '{{.Names}}' | grep -q "$name"; then
    echo "$PASS Container '$name' is running"
  fi
done

echo ""
echo "==> HTTP → HTTPS redirect (http://$DOMAIN)"
code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$DOMAIN" || echo "000")
check "HTTP returns 301/308" "$code" "30"

echo ""
echo "==> Bare domain redirect ($BARE → www)"
location=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 10 "https://$BARE" 2>/dev/null || echo "")
check "Redirect target contains www.$BARE" "$location" "www.$BARE"

echo ""
echo "==> HTTPS site responds (https://$DOMAIN)"
code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$DOMAIN" || echo "000")
check "HTTPS returns 200" "$code" "200"

echo ""
echo "==> TLS certificate issuer"
if command -v openssl &>/dev/null; then
  issuer=$(echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null \
    | openssl x509 -issuer -noout 2>/dev/null || echo "unavailable")
  echo "    Issuer: $issuer"
  check "Certificate issued by Let's Encrypt" "$issuer" "Let's Encrypt"
else
  echo "    openssl not found, skipping cert check"
fi

echo ""
if [[ $errors -eq 0 ]]; then
  echo "All checks passed."
else
  echo "$errors check(s) failed."
  exit 1
fi
