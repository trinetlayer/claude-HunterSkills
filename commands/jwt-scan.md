---
description: Test a JWT for common flaws (alg confusion, none, weak secret, kid/jku injection).
argument-hint: <paste the JWT or the request that carries it>
allowed-tools: Bash, Read
---

Analyze this JWT: $ARGUMENTS

Decode header+payload; then test: `alg:none`, RS256→HS256 key confusion (sign with the public key),
weak-secret crack (`hashcat -m 16500`), `kid` path-traversal/SQLi, `jku`/`x5u` SSRF, and expiry/`nbf`
handling. For BOLA, tamper `sub`/`role`/tenant claims and replay across two accounts. See the
`api-security-testing` skill's `references/jwt.md` for payload-level detail. Only on authorized targets.
