---
description: Rank a recon run's attack surface by impact × reachability, highest-value first.
argument-hint: [path to a trinet-recon run dir, or paste hosts/endpoints]
allowed-tools: Read, Grep, Glob
---

Rank the attack surface from: $ARGUMENTS (or the latest `./trinet-recon/*/` run dir).

Read the recon output (live hosts, endpoints, JS, nuclei hits). Rank the **top targets** by impact ×
reachability — auth portals, admin, APIs, staging/dev, dashboards, and endpoints with object IDs / file
or URL params first. For each, name the 1–2 highest-impact classes to try. Output a prioritized hit-list;
everything is a lead until it climbs the Validation Ladder.
