#!/usr/bin/env bash
# TrinetLayer — GhostJS + Dependency-Confusion scan via the public /api/v1 (real integration).
# Starts a GhostJS JS-recon/secret scan (optionally with Dependency-Confusion), polls to completion,
# and writes the findings JSON. Needs a Pro API key.
#
# Usage:
#   TRINETLAYER_API_KEY=gjs_xxx  ghostjs-scan.sh <target> [--mode deep|domain] [--dc] [--out FILE]
#
#   <target>            a domain you are AUTHORIZED to scan (e.g. example.com)
#   --mode deep|domain  deep = full JS/secret coverage (default); domain = faster, capped
#   --dc                also run Dependency-Confusion (reuses this scan's recon)
#   --out FILE          write the final report JSON here (default: ./ghostjs-<target>-<ts>.json)
#
# No key set → prints how to get one and exits 0 (the skill continues without it).

set -uo pipefail
BASE="${TRINETLAYER_API_BASE:-https://app.trinetlayer.com}"
TARGET=""; MODE="deep"; DC="false"; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-deep}"; shift 2 ;;
    --dc) DC="true"; shift ;;
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

if [ -z "${TRINETLAYER_API_KEY:-}" ]; then
  cat <<EOF
TrinetLayer GhostJS API key not set — skipping the hosted scan (this is optional).
To enable it: create a Pro API key at https://app.trinetlayer.com (Settings → API keys),
then re-run with:  TRINETLAYER_API_KEY=gjs_xxxxx ghostjs-scan.sh $TARGET
Continuing without GhostJS — use scripts/recon.sh + manual JS review instead.
EOF
  exit 0
fi
[ -n "$TARGET" ] || { echo "ERROR: no target. Usage: ghostjs-scan.sh <domain> [--mode deep|domain] [--dc]" >&2; exit 2; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl required." >&2; exit 2; }
JQ=0; command -v jq >/dev/null 2>&1 && JQ=1

TS="$(date +%Y%m%d-%H%M%S)"
OUT="${OUT:-./ghostjs-${TARGET}-${TS}.json}"
AUTH=(-H "Authorization: Bearer ${TRINETLAYER_API_KEY}")
get(){ curl -fsS "${AUTH[@]}" "$BASE$1" 2>/dev/null; }

echo "▶ GhostJS scan — target=$TARGET mode=$MODE dc=$DC  ($BASE)"

# start scan
START="$(curl -fsS -X POST "${AUTH[@]}" -H "Content-Type: application/json" \
  -d "{\"target\":\"${TARGET}\",\"mode\":\"${MODE}\",\"includeDependencyConfusion\":${DC}}" \
  "$BASE/api/v1/ghostjs/scan" 2>/dev/null)" || { echo "ERROR: scan start failed (check key/plan/quota — Pro required)." >&2; exit 1; }

if [ "$JQ" -eq 1 ]; then
  SID="$(printf '%s' "$START" | jq -r '.scan.id // .id // empty')"
else
  SID="$(printf '%s' "$START" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
fi
[ -n "$SID" ] || { echo "ERROR: no scan id in response:" >&2; echo "$START" >&2; exit 1; }
echo "  scan id: $SID  — polling…"

# poll report to completion (max ~20 min)
STATUS=""; REPORT=""
for i in $(seq 1 80); do
  sleep 15
  REPORT="$(get "/api/v1/ghostjs/report/$SID" || true)"
  [ -n "$REPORT" ] || continue
  if [ "$JQ" -eq 1 ]; then
    STATUS="$(printf '%s' "$REPORT" | jq -r '.status // .scan.status // empty' | tr '[:upper:]' '[:lower:]')"
  else
    STATUS="$(printf '%s' "$REPORT" | sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 | tr '[:upper:]' '[:lower:]')"
  fi
  printf '  [%02d] status: %s\r' "$i" "${STATUS:-?}"
  case "$STATUS" in
    done|completed|finished|success|failed|error) break ;;
  esac
done
echo

printf '%s' "$REPORT" > "$OUT"
case "$STATUS" in
  failed|error) echo "✖ scan ended: $STATUS (saved → $OUT)"; exit 1 ;;
  done|completed|finished|success) : ;;
  *) echo "⚠ still running/unknown after poll window (saved partial → $OUT)"; exit 0 ;;
esac

# summary
if [ "$JQ" -eq 1 ]; then
  echo "✔ GhostJS done → $OUT"
  printf '%s' "$REPORT" | jq -r '
    "  subdomains: \((.subdomains // []) | length)",
    "  js assets:  \((.jsAssets // .assets // []) | length)",
    "  secrets:    \((.findings // []) | length)"' 2>/dev/null || true
  # dependency-confusion block (combined scans include it; else fetch standalone if --dc)
  printf '%s' "$REPORT" | jq -e '.dependencyConfusion // .dc' >/dev/null 2>&1 \
    && printf '%s' "$REPORT" | jq -r '"  dep-confusion: \(((.dependencyConfusion // .dc).findings // []) | length)"'
else
  echo "✔ GhostJS done → $OUT (install 'jq' for a parsed summary)"
fi
echo "Feed secrets/endpoints back into the Map phase; verify every finding before reporting."
