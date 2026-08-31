# MCP integrations (optional)

These skills work fully on their own. If you also run **Burp**, **Caido**, **HackerOne**, or the
**ProjectDiscovery** tools, you can wire them to Claude Code as MCP servers so the skills can drive your
proxy, pull program scope, and run recon tools directly.

> **Opt-in, by design.** We do **not** ship an active root `.mcp.json` — a server command that isn't
> installed would break Claude Code startup. Instead, copy the entries you actually use from
> [`mcp.json.example`](mcp.json.example) into your own MCP config after installing each server.

## What each gives you

| Server | Transport | Gives Claude | Notes |
|--------|-----------|--------------|-------|
| **Burp Suite** — official [`PortSwigger/mcp-server`](https://github.com/PortSwigger/mcp-server) | SSE `127.0.0.1:9876` (+ bundled stdio proxy jar) | Proxy history, send-to-Repeater, scanner, Collaborator, config | Install the BApp, enable the **MCP** tab; point the proxy jar at the SSE URL. |
| **Caido** — community [`caido-mcp-server`](https://github.com/c0tton-fluff/caido-mcp-server) | stdio → Caido GraphQL | Proxy history, Replay, Automate, findings, scopes, match&replace | Set `CAIDO_URL` + a `CAIDO_ACCESS_TOKEN` PAT (Settings → Developer). |
| **HackerOne** — official [MCP](https://docs.hackerone.com/en/articles/16069077-hackerone-mcp-server-setup-tool-reference) | remote HTTP + OAuth (`https://hackerone.com/mcp`) | Programs, **scope**, assets, reports, analytics | **Read-only** — it cannot submit/modify. For submission use a community REST-wrapping server, **behind a human confirmation**. |
| **ProjectDiscovery** — community [`pd-tools-mcp`](https://github.com/intelligent-ears/pd-tools-mcp) | stdio (Node) | subfinder · dnsx · naabu · httpx · katana · nuclei | Install the PD binaries (`go install`) and build the server first. |

## How to enable

1. Install the server you want (see its repo). For Burp/Caido, start the app and enable its MCP/PAT.
2. Copy the matching block from `mcp.json.example` into your Claude Code MCP settings, fill in the real
   paths/tokens/URL, and remove the `_comment` keys.
3. Restart Claude Code (`/reload-plugins` if you keep it at the plugin root). The tools appear as
   `mcp__…__*` and the skills will use them where helpful (e.g. reading Burp/Caido proxy history during
   the Probe phase, pulling H1 scope during Map).

## Safety

Keep the same rules: the H1 official server is read-only; any **report submission or write** action goes
through a human confirmation, never an autopilot step. MCP just gives the skills better inputs — it does
not change the authorization gate or the Validation Ladder.
