#!/usr/bin/env bash
set -euo pipefail
SESSION_ID="${1:-}"
[ -n "$SESSION_ID" ] || SESSION_ID="$(date +%Y%m%d%H%M%S)-$$"
URL="${2:-}"
BASE="${TMPDIR:-/tmp}/design-from-url-${SESSION_ID}"
mkdir -p "$BASE"
printf '%s\n' "$URL" > "$BASE/reference-url.txt"
node - "$URL" "$BASE/pages.json" <<'NODEEOF'
const fs = require('fs');
const [url, out] = process.argv.slice(2);
fs.writeFileSync(out, JSON.stringify({primary:url,pages:[]}, null, 2) + '\n');
NODEEOF
printf '%s\n' "$BASE"
