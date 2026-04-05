#!/usr/bin/env bash
# setup/01-setup-traefik.sh
#
# One-time setup: deploy the shared Traefik reverse proxy on the server.
# Run this ONCE per server, before deploying any site.
#
# Usage:
#   bash setup/01-setup-traefik.sh [ACME_EMAIL] [TRAEFIK_DIR]
#
# Arguments:
#   ACME_EMAIL    Email for Let's Encrypt notifications (required)
#   TRAEFIK_DIR   Directory to install Traefik into (default: ~/traefik)

set -euo pipefail

ACME_EMAIL="${1:-}"
TRAEFIK_DIR="${2:-$HOME/traefik}"

# --- Validate ---
if [[ -z "$ACME_EMAIL" ]]; then
  echo "ERROR: ACME_EMAIL is required." >&2
  echo "Usage: $0 <email> [traefik-dir]" >&2
  exit 1
fi

if [[ ! "$ACME_EMAIL" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
  echo "ERROR: '$ACME_EMAIL' does not look like a valid email address." >&2
  exit 1
fi

# --- Checks ---
if ! command -v docker &>/dev/null; then
  echo "ERROR: docker is not installed or not in PATH." >&2
  exit 1
fi

if docker compose version &>/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose &>/dev/null; then
  COMPOSE="docker-compose"
else
  echo "ERROR: docker compose (v2) or docker-compose (v1) not found." >&2
  exit 1
fi

# --- Check if already running ---
if docker ps --format '{{.Names}}' | grep -q '^traefik'; then
  echo "A container named 'traefik' is already running. Skipping setup."
  echo "If you need to update it, run: cd $TRAEFIK_DIR && $COMPOSE pull && $COMPOSE up -d"
  exit 0
fi

# --- Install ---
echo "Creating Traefik directory at $TRAEFIK_DIR ..."
mkdir -p "$TRAEFIK_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_SRC="$SCRIPT_DIR/../traefik/docker-compose.yml"

if [[ ! -f "$COMPOSE_SRC" ]]; then
  echo "ERROR: traefik/docker-compose.yml not found at $COMPOSE_SRC" >&2
  exit 1
fi

echo "Copying traefik/docker-compose.yml to $TRAEFIK_DIR ..."
cp "$COMPOSE_SRC" "$TRAEFIK_DIR/docker-compose.yml"

echo "Setting ACME email to: $ACME_EMAIL"
sed -i "s/changeme@example.com/$ACME_EMAIL/" "$TRAEFIK_DIR/docker-compose.yml"

echo "Starting Traefik ..."
cd "$TRAEFIK_DIR"
$COMPOSE up -d

echo ""
echo "Traefik is running. The 'proxy' Docker network is ready."
echo "You can now deploy sites with: bash setup/02-deploy.sh"
