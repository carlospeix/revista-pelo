#!/usr/bin/env bash
# setup/02-deploy.sh
#
# Build and deploy the revista-pelo site.
# Requires the shared Traefik proxy to be running (see 01-setup-traefik.sh).
#
# Usage:
#   bash setup/02-deploy.sh [BASE_URL]
#
# Arguments:
#   BASE_URL   Hugo base URL (default: https://www.revistapelo.com.ar/)

set -euo pipefail

BASE_URL="${1:-https://www.revistapelo.com.ar/}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

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

if ! docker network ls --format '{{.Name}}' | grep -q '^proxy$'; then
  echo "ERROR: The 'proxy' Docker network does not exist." >&2
  echo "Run setup/01-setup-traefik.sh first." >&2
  exit 1
fi

# --- Deploy ---
cd "$PROJECT_DIR"

echo "Building and deploying revista-pelo (BASE_URL=$BASE_URL) ..."
$COMPOSE build --build-arg HUGO_BASE_URL="$BASE_URL"
$COMPOSE up -d

echo ""
echo "Deployed. Site should be live at $BASE_URL"
echo "To check container status: docker compose ps"
echo "To tail logs:              docker compose logs -f web"
