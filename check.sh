#!/usr/bin/env bash
set -euo pipefail

rm -rf public

# Build with a local base URL so checks stay fully internal.
hugo --baseURL "http://localhost/"

# Validate links while ignoring local and static file host URLs.
htmlproofer ./public --no-enforce-https --ignore-urls "/^http:\/\/localhost\//,/^https:\/\/files\.revistapelo\.com\.ar\//"
