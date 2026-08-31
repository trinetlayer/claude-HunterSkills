#!/usr/bin/env bash
# TrinetLayer — scope-gated web/API recon pipeline.
# Chains passive→active recon with sane defaults, skips any missing tool, throttles (no DoS),
# and writes a structured run directory you can feed back into the skills' Map phase.
#
# Usage:
#   recon.sh <target-domain> --yes-authorized [--out DIR] [--deep] [--rl N]
#
#   <target-domain>     e.g. example.com  (a domain/host you are AUTHORIZED to test)
#   --yes-authorized    required — asserts this target is in scope (your responsibility)
#   --out DIR           output dir (default: ./trinet-recon/<target>-<ts>)
#   --deep              deeper crawl (katana -d 3, more sources) — noisier
#   --rl N              global rate limit hint for nuclei/httpx (default 50)
#
# Tools used if present (each skipped gracefully if absent): subfinder, httpx, katana,
# gau, waybackurls, nuclei, arjun, dnsx. Install what you use; nothing here is mandatory.

set -uo pipefail

TARGET=""; AUTH=0; OUT=""; DEEP=0; RL=50
while [ $# -gt 0 ]; do
  case "$1" in
    --yes-authorized) AUTH=1; shift ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --deep) DEEP=1; shift ;;
    --rl) RL="${2:-50}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

if [ -z "$TARGET" ]; then
  echo "ERROR: no target given." >&2
  sed -n '2,20p' "$0" >&2
  exit 2
fi
if [ "$AUTH" -ne 1 ]; then
  cat >&2 <<EOF
REFUSED: pass --yes-authorized to confirm '$TARGET' is in scope for you
(your own asset, an in-scope bug-bounty target, or a signed engagement).
No scope, no scan. See the shared RULES: authorization first.
EOF
  exit 3
fi
# basic sanity on the target (domain/host only, no scheme/paths/spaces)
case "$TARGET" in
  *" "*|*/*|http*|*:*) echo "ERROR: give a bare domain/host, e.g. example.com" >&2; exit 2 ;;
esac

TS="$(date +%Y%m%d-%H%M%S)"
OUT="${OUT:-./trinet-recon/${TARGET}-${TS}}"
mkdir -p "$OUT"
echo "▶ TrinetLayer recon — target=$TARGET  out=$OUT  deep=$DEEP  rl=$RL"

have(){ command -v "$1" >/dev/null 2>&1; }
skip(){ echo "  · skip ($1 not installed)"; }
# run a tool with a hard time cap so a slow/stuck target never hangs the pipeline
TO(){ local d="$1"; shift; if have timeout; then timeout "$d" "$@"; elif have gtimeout; then gtimeout "$d" "$@"; else "$@"; fi; }

# 1) subdomains (passive)
echo "[1/5] subdomains"
if have subfinder; then
  TO 180 subfinder -d "$TARGET" -all -silent 2>/dev/null | sort -u > "$OUT/subs.txt" || true
else skip subfinder; printf '%s\n' "$TARGET" > "$OUT/subs.txt"; fi
[ -s "$OUT/subs.txt" ] || printf '%s\n' "$TARGET" > "$OUT/subs.txt"
if have dnsx; then TO 180 dnsx -l "$OUT/subs.txt" -silent 2>/dev/null | sort -u > "$OUT/resolved.txt" || true; fi

# 2) live hosts + tech
echo "[2/5] live hosts"
if have httpx; then
  TO 300 httpx -l "$OUT/subs.txt" -silent -sc -title -tech-detect -server -rl "$RL" 2>/dev/null > "$OUT/live.txt" || true
  awk '{print $1}' "$OUT/live.txt" 2>/dev/null | sort -u > "$OUT/live-urls.txt" || true
else skip httpx; sed 's#^#https://#' "$OUT/subs.txt" > "$OUT/live-urls.txt"; fi

# 3) crawl + historical URLs
echo "[3/5] urls / crawl"
: > "$OUT/urls.txt"
DEPTH=2; [ "$DEEP" -eq 1 ] && DEPTH=3
if have katana; then
  TO 300 katana -list "$OUT/live-urls.txt" -jc -kf all -d "$DEPTH" -silent 2>/dev/null >> "$OUT/urls.txt" || true
else skip katana; fi
if have gau; then TO 150 gau --subs "$TARGET" 2>/dev/null >> "$OUT/urls.txt" || true
elif have waybackurls; then TO 150 waybackurls "$TARGET" 2>/dev/null >> "$OUT/urls.txt" || true
else skip "gau/waybackurls"; fi
sort -u "$OUT/urls.txt" -o "$OUT/urls.txt" 2>/dev/null || true
grep -iE '\.js(\?|$)' "$OUT/urls.txt" 2>/dev/null | sort -u > "$OUT/js.txt" || true
grep -iE '\?|=|/api/|/v[0-9]/|graphql' "$OUT/urls.txt" 2>/dev/null | sort -u > "$OUT/params-endpoints.txt" || true

# 4) templated vuln scan (throttled, medium+)
echo "[4/5] nuclei (throttled)"
if have nuclei && [ -s "$OUT/live-urls.txt" ]; then
  TO 600 nuclei -l "$OUT/live-urls.txt" -severity medium,high,critical -rl "$RL" -silent 2>/dev/null > "$OUT/nuclei.txt" || true
else skip nuclei; fi

# 5) summary
echo "[5/5] summary"
c(){ [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo 0; }
cat > "$OUT/summary.txt" <<EOF
TrinetLayer recon summary
target:            $TARGET
generated:         $TS
subdomains:        $(c "$OUT/subs.txt")
live hosts:        $(c "$OUT/live.txt")
urls (crawled):    $(c "$OUT/urls.txt")
js assets:         $(c "$OUT/js.txt")
param/endpoints:   $(c "$OUT/params-endpoints.txt")
nuclei findings:   $(c "$OUT/nuclei.txt")

Next: rank live hosts by impact × reachability, pull secrets from js.txt
(or run scripts/ghostjs-scan.sh), then test highest-impact classes first.
Every finding must climb the Trinet Validation Ladder before you report it.
EOF
cat "$OUT/summary.txt"
echo "✔ recon done → $OUT"
