---
description: Run the guarded autonomous hunt-loop on one authorized target (scope→recon→hunt→validate→report).
argument-hint: <target> — an asset you're authorized to test
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/recon.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ghostjs-scan.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/memory.sh *), Read, Grep, Glob
---

Autopilot the target: `$ARGUMENTS`

Delegate to the **autopilot** agent. It runs the full loop but **stops at mandatory human checkpoints**
(after scope, before active testing, before any state-changing exploitation, before submitting). It
never touches out-of-scope hosts, never DoS/sprays, and never exploits destructively without your
explicit go-ahead.

First confirm authorization + the in-scope allowlist. No scope → advisory mode only, no traffic.
