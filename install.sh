#!/usr/bin/env bash
# TrinetLayer Bug-Hunting Skills — installer (skills only)
# Copies (or symlinks) every skill under ./skills into your Claude Code skills directory.
#
# NOTE: this script installs the SKILLS only. The slash commands (/recon, /autopilot, …)
# and the autopilot / recon-runner subagents ship with the PLUGIN install, which also sets
# the ${CLAUDE_PLUGIN_ROOT} the bundled scripts need. For the full experience run, inside
# Claude Code:
#     /plugin marketplace add trinetlayer/claude-HunterSkills
#     /plugin install trinetlayer-bug-hunting@trinetlayer
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
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Auto-discover every skill folder under skills/ so this never goes stale as skills are added.
SKILLS=()
for src in "$SRC"/*/; do
  [[ -d "$src" ]] || continue
  SKILLS+=("$(basename "$src")")
done

if [[ ${#SKILLS[@]} -eq 0 ]]; then
  echo "✖ No skills found in $SRC — run this from the repo root." >&2
  exit 1
fi

if [[ "$UNINSTALL" == "1" ]]; then
  for s in "${SKILLS[@]}"; do rm -rf "${DEST:?}/$s"; done
  echo "✔ Removed ${#SKILLS[@]} TrinetLayer skill folders from $DEST"
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
printf '  %s\n' "${SKILLS[@]}"
echo
echo "Restart Claude Code (or start a new session), then just ask —"
echo '  e.g. "help me hunt bugs on this authorized target" — and the'
echo "  bug-hunting-orchestrator will route to the right skill."
echo
echo "Want the slash commands (/recon, /autopilot, …) and subagents too? Install as a plugin:"
echo "  /plugin marketplace add trinetlayer/claude-HunterSkills"
echo "  /plugin install trinetlayer-bug-hunting@trinetlayer"
