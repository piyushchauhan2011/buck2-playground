# Sparse Checkout Playbook

This repo uses Git blobless clone + cone-mode sparse checkout to keep local
and CI environments fast.  Teams only materialise the directories they actually
need.

Sparse checkout **profiles** are committed JSON files in `common/profiles/`
that list which directories each team needs.  The monorepo tooling
(`libs/monorepo-tooling`) reads these files and runs `git sparse-checkout set`.

---

## Profile files

Profiles live at `common/profiles/<name>.json`.  Base directories
(`scripts`, `.github`, `toolchains`, `common/profiles`) are always included
in every checkout and do **not** need to be listed in the profile.

| Profile    | Owner                          | Directories checked out                         |
|------------|--------------------------------|-------------------------------------------------|
| `backend`  | Backend team                   | `domains/api`, `domains/backend`, `libs/common` |
| `frontend` | Frontend / JS team             | `domains/api/js`, `domains/api`, `libs/common`  |
| `ml`       | ML / Data team                 | `domains/ml`, `libs/common`                     |
| `infra`    | Infrastructure / Platform team | `domains/infra`, `libs/common`                  |
| `jvm`      | JVM team                       | `domains/jvm`, `libs/common`                    |

### Profile JSON format

```json
{
  "owner": "Team name",
  "purpose": "One-line description of what this profile covers.",
  "includeFolders": [
    "domains/my-domain",
    "libs/common"
  ]
}
```

### Add a directory to an existing profile

Edit `common/profiles/<name>.json` and add the path to `includeFolders`.
Commit the change — teammates pick it up automatically on their next checkout.

### Create a new profile

1. Create `common/profiles/my-team.json` following the format above.
2. Add the profile name to the `options` list in `.github/workflows/profile.yml`.
3. Add it to the matrix `fromJson` arrays in the same file.
4. Update the table above.

---

## 1. Developer workstation

### Fresh clone

Use the monorepo tooling to handle all steps in one command:

```bash
node libs/monorepo-tooling/dist/cli.js sparse-checkout new-clone frontend https://github.com/org/monorepo.git
```

(Requires `pnpm install` and `pnpm --filter @repo/monorepo-tooling build` first, or run from a repo that already has the tooling built.)

Or manually:

```bash
git clone --filter=blob:none --no-checkout https://github.com/org/monorepo.git
cd monorepo
git sparse-checkout init --cone
git sparse-checkout set common/profiles scripts .github toolchains build_defs libs/monorepo-tooling
git checkout
node libs/monorepo-tooling/dist/cli.js sparse-checkout apply frontend
```

### Switch profile on an existing clone

```bash
node libs/monorepo-tooling/dist/cli.js sparse-checkout apply frontend
```

### List available profiles

```bash
node libs/monorepo-tooling/dist/cli.js sparse-checkout list
```

### Combine profiles (e.g. touching a shared library)

```bash
FRONTEND_DIRS=$(jq -r '.includeFolders[]' common/profiles/frontend.json)
BACKEND_DIRS=$(jq -r '.includeFolders[]'  common/profiles/backend.json)
git sparse-checkout set common/profiles scripts .github toolchains build_defs libs/monorepo-tooling \
  $FRONTEND_DIRS $BACKEND_DIRS
```

---

## 2. Pull request CI — affected targets only

**Workflow**: `.github/workflows/affected.yml`
**Trigger**: every PR against `main` / `master`

Dynamically computes the minimum set of directories to check out based on what
the PR actually changed.  Static profiles do not fit this model — the affected
dirs are computed at runtime via `buck2 uquery rdeps()`.

```
Phase 1 — blobless clone + sparse cone (scripts/ .github/ toolchains/).
           Materialise ALL BUCK files via git cat-file (tiny Starlark text).
           Install Buck2.
           Run buck2 uquery rdeps(//..., changed-targets).

Phase 2 — git sparse-checkout set <affected dirs>
           Install toolchains (Node / Python) only if needed.
           buck2 build / test.
```

---

## 3. Profile CI — full domain sweep

**Workflow**: `.github/workflows/profile.yml`
**Triggers**:
- `workflow_dispatch` — run any named profile on demand (dropdown in GitHub UI)
- `schedule` (nightly Mon–Fri 02:00 UTC) — all profiles run in parallel

```
Phase 1 — blobless clone + cone including common/profiles/
           so profile JSON files are on disk.

Phase 2 — jq reads includeFolders from common/profiles/<name>.json
           git sparse-checkout set <profile dirs>
           Install Buck2.
           Detect toolchains (Node / Python) from profile dirs.
           buck2 build //dir/... (covers all quality genrule targets).
           buck2 test  //dir/...
```

### Run a profile manually

```bash
# From GitHub UI: Actions → Profile CI → Run workflow → pick a profile

# From CLI:
gh workflow run profile.yml -f profile=frontend
```

### When to run a profile manually

| Situation                                  | Recommended profile             |
|--------------------------------------------|---------------------------------|
| Before a release of the JS API             | `frontend`                      |
| Investigating a nightly failure            | the failing profile             |
| After updating `libs/common`               | `backend` + `frontend`          |
| Onboarding — verify your local setup       | your team's profile             |

---

## Cone mode

All sparse checkout in this repo uses **cone mode** (the default since Git
2.37), which restricts patterns to whole directories.

```bash
git sparse-checkout list     # inspect the active cone
git sparse-checkout reapply  # reapply patterns after a merge
```

---

## Two-sentence summary

> **Profiles** (`common/profiles/*.json`) define what each team needs locally
> and for nightly CI. The monorepo tooling (`libs/monorepo-tooling`) applies
> them via `git sparse-checkout`.  For PR CI, `buck2 uquery rdeps()` computes
> the minimum affected set dynamically — no profile needed.
