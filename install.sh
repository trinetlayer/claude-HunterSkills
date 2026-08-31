#!/usr/bin/env bash
# TrinetLayer Bug-Hunting Skills — installer
# Copies (or symlinks) the skills into your Claude Code skills directory.
#
# Usage:
#   ./install.sh                 # copy skills to ~/.claude/skills (personal, global)
#   ./install.sh --link          # symlink instead of copy (auto-updates on git pull)
#   ./install.sh --project DIR    # install into DIR/.claude/skills (project-scoped)
#   ./install.sh --uninstall      # remove the installed TrinetLayer skills

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO_DIR/skills"
MODE="copy"
DEST="$HOME/.claude/skills"
UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --link) MODE="link"; shift ;;
    --project) DEST="${2%/}/.claude/skills"; shift 2 ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

SKILLS=(bug-hunting-orchestrator web-app-pentest api-security-testing \
        source-code-review android-pentest ios-pentest smart-contract-audit shared)

if [[ "$UNINSTALL" == "1" ]]; then
  for s in "${SKILLS[@]}"; do rm -rf "${DEST:?}/$s"; done
  echo "✔ Removed TrinetLayer skills from $DEST"
  exit 0
fi

mkdir -p "$DEST"
for s in "${SKILLS[@]}"; do
  rm -rf "${DEST:?}/$s"
  if [[ "$MODE" == "link" ]]; then
    ln -s "$SRC/$s" "$DEST/$s"
  else
    cp -R "$SRC/$s" "$DEST/$s"
  fi
done

echo "✔ Installed ${#SKILLS[@]} skill folders into $DEST ($MODE)"
echo "  Skills: web-app-pentest, api-security-testing, source-code-review,"
echo "          android-pentest, ios-pentest, smart-contract-audit + orchestrator"
echo
echo "Restart Claude Code (or start a new session), then just ask —"
echo '  e.g. "help me hunt bugs on this authorized target" — and the'
echo "  bug-hunting-orchestrator will route to the right skill."
