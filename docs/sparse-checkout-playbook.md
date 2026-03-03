# Sparse Checkout Playbook

This repo uses Git's blobless clone + sparse checkout in three distinct ways.
They are complementary — use whichever fits the situation.

---

## 1. Developer workstation — team profile

A new developer on the frontend team only needs `domains/api/js` and
`libs/common`.  They should never have to clone the ML or JVM directories.

### Fresh clone with a profile

```bash
git clone --filter=blob:none --sparse https://github.com/org/monorepo.git
cd monorepo
git sparse-checkout set $(cat scripts/sparse-checkout-profiles/frontend | tr '\n' ' ')
```

### Switch profile on an existing clone

```bash
./scripts/sparse-checkout.sh frontend
```

### Available profiles

| Profile    | Directories checked out                            |
|------------|----------------------------------------------------|
| `backend`  | `domains/api`, `domains/backend`, `libs/common`   |
| `frontend` | `domains/api/js`, `domains/api`, `libs/common`    |
| `ml`       | `domains/ml`, `libs/common`                       |
| `infra`    | `domains/infra`, `libs/common`                    |
| `jvm`      | `domains/jvm`, `libs/common`                      |

Profile files are plain text at `scripts/sparse-checkout-profiles/<name>`.
Add a new line to extend a profile; create a new file to add a profile.

---

## 2. Pull request CI — affected targets only

**Workflow**: `.github/workflows/affected.yml`  
**Trigger**: every PR against `main` / `master`

Checks out the *minimum* set of directories needed to build and test only the
targets transitively affected by the PR's changes.

```
Phase 1 — blobless clone + scripts/toolchains cone only.
          Materialise ALL BUCK files (tiny text) via git cat-file.
          Install Buck2.
          Run buck2 uquery rdeps(//..., changed-targets) to find consumers.

Phase 2 — git sparse-checkout set <affected dirs>
          Install toolchains (Node / Python) only if needed.
          buck2 build / test / quality on affected targets only.
```

This keeps CI fast: a PR touching only `domains/api/python` never downloads
the JS `node_modules` or the JVM toolchain.

---

## 3. Profile CI — full domain sweep

**Workflow**: `.github/workflows/profile.yml`  
**Triggers**:
- `workflow_dispatch` — developer runs a named profile on demand
- `schedule` (nightly Mon–Fri 02:00 UTC) — all profiles run in parallel

Use this to answer: *"Does everything in my team's domain still pass?"*

Complements PR CI: PR CI is surgical; profile CI is a safety net that catches
issues (e.g. dependency rot, flaky tests) that don't show up in focused diffs.

### Run a profile manually

Go to **Actions → Profile CI → Run workflow**, pick a profile from the
dropdown, and click **Run**.

Or from the CLI:

```bash
gh workflow run profile.yml -f profile=frontend
```

### When to run a profile manually

| Situation | Recommended profile |
|-----------|---------------------|
| Before cutting a release for the JS API | `frontend` |
| Investigating a nightly failure | the failing profile |
| After updating a shared lib (`libs/common`) | `backend` + `frontend` |
| Onboarding — verifying your local setup | your team's profile |

---

## Cone mode

All sparse-checkout calls in this repo use **cone mode** (the default since
Git 2.37), which restricts patterns to whole directories.  Cone mode is
significantly faster than non-cone mode on large repos because Git can use
directory-level bitmaps rather than checking every path.

```bash
git sparse-checkout init --cone    # already the default
git sparse-checkout set dir1 dir2
git sparse-checkout list           # inspect current cone
```

## Add a new team profile

1. Create `scripts/sparse-checkout-profiles/<team>` with one directory per line.
2. Add the profile name to the `options` list in `.github/workflows/profile.yml`
   under `inputs.profile` and the two `fromJson` arrays.
3. Update the table above.
