#!/usr/bin/env bash
# TrinetLayer — persistent hunt memory (JSONL). Lets insight from one target/session inform the next.
# Backs the /remember, /pickup and /chain commands. Read/append only — never runs any test.
#
# Usage:
#   memory.sh append <target> <status> <class> <note...>   # status: lead|confirmed|dead
#   memory.sh query  <target>                               # entries for one target
#   memory.sh list                                          # all targets + counts
#   memory.sh gc                                            # rotate if over the size cap
#   memory.sh path                                          # print the store path
#
# Store: ${CLAUDE_PLUGIN_DATA}/hunt-memory.jsonl  (falls back to ./.trinet/hunt-memory.jsonl)

set -uo pipefail

DIR="${CLAUDE_PLUGIN_DATA:-./.trinet}"
STORE="$DIR/hunt-memory.jsonl"
CAP=$((5 * 1024 * 1024))   # 5 MB
mkdir -p "$DIR" 2>/dev/null || true

# JSON-escape a string (backslash, quote, tab, newline, CR)
esc(){ printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' | tr -d '\r' | awk 'BEGIN{ORS=""} {if(NR>1)printf("\\n"); printf("%s",$0)}'; }

cmd="${1:-}"; shift 2>/dev/null || true
case "$cmd" in
  append)
    target="${1:-}"; status="${2:-lead}"; class="${3:-}"; shift 3 2>/dev/null || true
    note="$*"
    [ -n "$target" ] || { echo "usage: memory.sh append <target> <status> <class> <note>" >&2; exit 2; }
    case "$status" in lead|confirmed|dead) ;; *) status="lead" ;; esac
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '{"ts":"%s","target":"%s","status":"%s","class":"%s","note":"%s"}\n' \
      "$ts" "$(esc "$target")" "$status" "$(esc "$class")" "$(esc "$note")" >> "$STORE"
    echo "✔ remembered [$status] $class @ $target"
    "$0" gc >/dev/null 2>&1 || true
    ;;
  query)
    target="${1:-}"; [ -n "$target" ] || { echo "usage: memory.sh query <target>" >&2; exit 2; }
    [ -f "$STORE" ] || { echo "(no memory yet)"; exit 0; }
    if command -v jq >/dev/null 2>&1; then
      jq -c --arg t "$target" 'select(.target==$t)' "$STORE" 2>/dev/null || grep -F "\"target\":\"$target\"" "$STORE"
    else
      grep -F "\"target\":\"$target\"" "$STORE" 2>/dev/null || echo "(nothing for $target)"
    fi
    ;;
  list)
    [ -f "$STORE" ] || { echo "(no memory yet)"; exit 0; }
    if command -v jq >/dev/null 2>&1; then
      jq -r '.target' "$STORE" 2>/dev/null | sort | uniq -c | sort -rn
    else
      sed -n 's/.*"target":"\([^"]*\)".*/\1/p' "$STORE" | sort | uniq -c | sort -rn
    fi
    ;;
  gc)
    [ -f "$STORE" ] || exit 0
    sz=$(wc -c < "$STORE" 2>/dev/null | tr -d ' ')
    if [ "${sz:-0}" -gt "$CAP" ]; then
      rm -f "$STORE.bak3" 2>/dev/null
      [ -f "$STORE.bak2" ] && mv "$STORE.bak2" "$STORE.bak3"
      [ -f "$STORE.bak1" ] && mv "$STORE.bak1" "$STORE.bak2"
      mv "$STORE" "$STORE.bak1"
      tail -n 500 "$STORE.bak1" > "$STORE" 2>/dev/null || : > "$STORE"
      echo "rotated hunt memory (kept last 500 entries; 3 backups)"
    fi
    ;;
  path) echo "$STORE" ;;
  *) sed -n '2,14p' "$0"; exit 0 ;;
esac
