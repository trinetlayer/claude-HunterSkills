# BOLA / IDOR Deep Dive (API1:2023 object-level & API3 property-level authz)

Object-level authorization is the #1 API risk. The proof is always the same: an object reference you
can reach that returns **another** tenant's data or mutates **their** record. Accessing your *own*
object by ID is never a bug — you must cross a boundary. Prove with two accounts (A, B) + an unauth
session.

> Curated from TrinetLayer Learn (learn.trinetlayer.com).

---

## 1. Recon — map references before tampering

For every endpoint, catalogue the object reference and its **type**, because the type dictates the
attack:

| Ref type | Example | Attack |
| --- | --- | --- |
| Sequential numeric | `user_id=12345` | ±1, then range-enumerate |
| UUID | `550e8400-…` | v4 = infeasible; check for **v1** (timestamp/MAC-based) → predictable |
| Base64 / hex | `/api/user/MTIzNDU=` (`12345`) | decode → modify → re-encode |
| Unsalted hash | `md5("12345")` | precompute `hash(1..N)` and iterate |
| Hashids / short codes | `/o/aB3xK` | if the alphabet/salt is default or leaked, forge neighbours |
| File path / slug | `user123_invoice.pdf` | swap owner token; combine with path traversal (`../`) |

Also record **who should reach each** `{method, path, param}` so a 200 across the boundary is
immediately a finding. Discover hidden object params with **arjun** (`user_id`, `uid`, `account`,
`profile_id`, `owner_id`) — an endpoint with no visible ID may still bind one.

---

## 2. Enumeration

```python
import requests
for i in range(1, 100000):                       # sequential IDs
    r = requests.get(f"https://api.tgt.com/user/{i}",
                     headers={"Authorization": "Bearer <B>"})   # replay as user B
    if r.status_code == 200:
        print("reachable:", i)                    # cross-tenant read
```

- **Response diffing** — status, length, and body fields separate valid-but-forbidden from
  not-found. Even with identical error bodies, **timing** can leak validity (valid IDs do more work).
- **Automate serially and throttled**, honoring program limits; back off on `429`, note `403` (authz
  present). Never parallel-flood a live target.

---

## 3. Reference-obfuscation bypass (encoding ≠ authorization)

Opaque-looking IDs are usually reversible. Encoding, not encryption:

```
# base64 integer
GET /api/invoice/MTA0Mw==        # base64('1043')  -> decode, ++ , re-encode
GET /api/invoice/MTA0NA==        # base64('1044')  another tenant

# double / URL encoding to dodge a filter
/api/user/%2531%2532%2533        # double-encoded 123

# keyless hash oracle: precompute md5(1..N), iterate
```

If the transform is **keyless** (encoding or *unsalted* hash), the reference is still guessable — flag
it as effective IDOR. Only a keyed MAC / random-and-stored token actually resists this.

---

## 4. Routes that skip the check

The primary UI often enforces authz while bolt-on routes don't:

- **Export / report / invoice-PDF / bulk-download** — `GET /api/reports/export?account_id=1044&format=pdf`,
  or a guessable pre-signed blob `/exports/2024/account-1044-statement.pdf`.
- **Batch / array params** — weaker validation on collections:
  `GET /api/users?ids[]=1&ids[]=2&ids[]=3` · `POST /api/delete {"user_ids":[1,2,3,4]}`.
- **Alternate transports** — cookie-borne IDs (`Cookie: user_id=12346`), file-upload `user_id` fields
  (overwrite another user's file), WebSocket subscribe frames
  (`{"action":"subscribe","user_id":12346,"channel":"private_messages"}`), and different **subdomains**
  (`admin.`, `internal.`, `api.`) that reuse the same IDs with different authz implementations.
- **Method / verb & override** — a route `403` on `GET` may `200` on `POST`/`PUT`; try
  `X-HTTP-Method-Override: DELETE`.
- **Referer-trusting authz** — some apps gate on the `Referer` header; spoof it.

---

## 5. Property-level authz — mass assignment (API3)

BOLA's write-side sibling: inject fields the client never exposes so the ORM auto-binds them.

```
PUT /api/users/1043
{ "name":"Mallory", "role":"admin", "owner_id":1, "is_admin":true,
  "email_verified":true, "account_balance":999999, "verified":true }
```

Frameworks that mass-bind request bodies (Rails, Spring, Django, Mongoose/Node) accept these unless an
explicit allowlist (strong params / DTO) is enforced. Combine with IDOR (`PUT` another user's id +
extra fields) to reassign or elevate their record. Fuzz **every** update/create body with `role`,
`isAdmin`, `owner_id`, `account_id`, `price`, `verified` and diff the response. Also check the read
side (**excessive data exposure**): the API response may carry `password_hash` / internal flags the UI
filters — that's the same object over-serialized.

---

## 6. GraphQL BOLA

- **Node IDs** — global `node(id: "…")` / Relay IDs are often base64 of `Type:pk`; decode, swap the pk,
  refetch another tenant's object bypassing the REST-route check.
- **Nested edges** — reach a protected object through a relation the resolver forgot to guard:
  `user(id:12345){ orders{ items } privateDocuments{ url } }`. Authz is frequently enforced at the
  top query but not on nested fields/edges.
- **Mutations** — object-level checks are commonly missing on mutations even when present on queries.

See [graphql.md](graphql.md) for introspection, batching/aliasing, and copy-pasteable queries.

---

## 7. Methodology & quick wins

1. Two accounts (A, B) + unauth, live in Burp/Postman with their tokens.
2. Do all actions as A, capture requests, **replay each as B** and diff — horizontal (peer) and
   vertical (privilege) both.
3. Sweep every ID-bearing **GET** across sessions before touching writes.
4. Decode/enumerate opaque refs; hit export/batch/WebSocket/subdomain variants.
5. On writes, add unexpected fields (mass assignment) and diff responses for over-exposure.
6. Also try with **no** auth — public IDOR.

**Red flags:** sequential IDs in URLs/params; predictable filenames; user IDs echoed in responses or JS
bundles; the same endpoint answering for different IDs; errors that distinguish valid vs invalid IDs.

**Report as:** *API1:2023 BOLA* (CWE-639/CWE-284/CWE-285) or *API3:2023* mass assignment (CWE-915) /
excessive data exposure (CWE-201). Chain BOLA + excessive data exposure = full-tenant read; state the
attacker outcome ("any user reads/edits any other user's records"), give the two-account repro, and
prescribe server-side object-level authz keyed to the **session**, not the client-supplied ID.
