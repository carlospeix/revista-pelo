#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration (set via Codespaces secrets or a local .env file)
# ---------------------------------------------------------------------------
LOCAL_DIR="public"
SYNC_DIR="sync-public"

# Load variables from .env if present
if [[ -f ".env" ]]; then
  # shellcheck source=.env
  source .env
fi

# Validate required environment variables
error=0
for var in FTP_HOST FTP_PORT FTP_USER FTP_REMOTE_PATH FTP_PASSWORD; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: ${var} is not set." >&2
    error=1
  fi
done
if [[ $error -eq 1 ]]; then
  echo "       Set them as Codespaces secrets (repo Settings → Secrets → Codespaces)" >&2
  echo "       or create a local .env file based on .env.example." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Build
# ---------------------------------------------------------------------------
echo "==> Cleaning previous build..."
rm -rf "$LOCAL_DIR"

echo "==> Building site with Hugo..."
hugo

if [[ -f ".htaccess" ]]; then
  echo "==> Including .htaccess in build output..."
  cp ".htaccess" "${LOCAL_DIR}/.htaccess"
fi

echo "==> Build complete."

# ---------------------------------------------------------------------------
# 2. Detect changes vs last deploy (checksum-based, local only)
# ---------------------------------------------------------------------------
echo "==> Detecting changes since last deploy..."
mkdir -p "$SYNC_DIR"

mapfile -t UPLOAD_LIST < <(rsync --archive --checksum --delete \
      --dry-run --out-format="%o %n" \
      --exclude .DS_Store \
      --exclude .git/ \
      "$LOCAL_DIR/" "$SYNC_DIR/" | grep "^send " | grep -v '/$' | awk '{print $2}')

mapfile -t DELETE_LIST < <(rsync --archive --checksum --delete \
      --dry-run --out-format="%o %n" \
      --exclude .DS_Store \
      --exclude .git/ \
      "$LOCAL_DIR/" "$SYNC_DIR/" | grep "^del\. " | awk '{print $2}')

echo "  Files to upload: ${#UPLOAD_LIST[@]}"
for f in "${UPLOAD_LIST[@]}"; do echo "    + $f"; done
echo "  Files to delete: ${#DELETE_LIST[@]}"
for f in "${DELETE_LIST[@]}"; do echo "    - $f"; done

if [[ ${#UPLOAD_LIST[@]} -eq 0 && ${#DELETE_LIST[@]} -eq 0 ]]; then
  echo "==> Nothing changed, skipping upload."
  exit 0
fi

# ---------------------------------------------------------------------------
# 3. Deploy via FTP (only changed files)
# ---------------------------------------------------------------------------
echo "==> Uploading to ${FTP_HOST}:${FTP_REMOTE_PATH} ..."

LFTP_SCRIPT=$(mktemp)
trap 'rm -f "$LFTP_SCRIPT"' EXIT

cat >> "$LFTP_SCRIPT" <<LFTP_SETTINGS
set ftp:ssl-allow yes
set ftp:ssl-force no
set ssl:verify-certificate no
set net:max-retries 3
set net:reconnect-interval-base 5
LFTP_SETTINGS

for file in "${DELETE_LIST[@]}"; do
  echo "rm -f \"${FTP_REMOTE_PATH%/}/${file}\"" >> "$LFTP_SCRIPT"
done

for file in "${UPLOAD_LIST[@]}"; do
  dir=$(dirname "$file")
  if [[ "$dir" != "." ]]; then
    # Only mkdir if this directory is new (not in last deploy)
    if [[ ! -d "${SYNC_DIR}/${dir}" ]]; then
      echo "mkdir -p \"${FTP_REMOTE_PATH%/}/${dir}\"" >> "$LFTP_SCRIPT"
    fi
    echo "put -O \"${FTP_REMOTE_PATH%/}/${dir}\" \"${LOCAL_DIR}/${file}\"" >> "$LFTP_SCRIPT"
  else
    echo "put -O \"${FTP_REMOTE_PATH}\" \"${LOCAL_DIR}/${file}\"" >> "$LFTP_SCRIPT"
  fi
done

echo "bye" >> "$LFTP_SCRIPT"

lftp -u "$FTP_USER","$FTP_PASSWORD" -p "$FTP_PORT" "ftp://$FTP_HOST" < "$LFTP_SCRIPT"

# ---------------------------------------------------------------------------
# 4. Update sync-public to reflect what was just deployed
# ---------------------------------------------------------------------------
rsync --archive --checksum --delete \
      --exclude .DS_Store \
      --exclude .git/ \
      "$LOCAL_DIR/" "$SYNC_DIR/"

echo "==> Deploy complete."
