# Sparse Checkout Playbook

This repo uses Git blobless clone + sparse checkout in three distinct ways —
local developer onboarding, PR CI, and nightly profile sweeps.

Sparse checkout profiles are managed with **[Sparo](https://tiktok.github.io/sparo/)**,
a Git sparse-checkout manager from TikTok.  Sparo stores profiles as committed
JSON files and generates cone-mode patterns automatically.

> **Rush vs Buck2**: Sparo's `selections` field (e.g. `--to`, `--from`)
> requires a [RushJS](https://rushjs.io/) workspace to resolve project
> dependencies.  This repo uses Buck2 — not Rush — so profiles use
> `includeFolders` only.  Transitive dependency resolution in CI is handled by
> `buck2 uquery rdeps()` in `affected.yml`.

---

## Sparo profile files

Profiles live at `common/sparo-profiles/<name>.json` and are committed to Git
so they version with the code.

| Profile    | Owner           | Directories checked out                            |
|------------|-----------------|----------------------------------------------------|
| `backend`  | Backend team    | `domains/api`, `domains/backend`, `libs/common`   |
| `frontend` | Frontend/JS     | `domains/api/js`, `domains/api`, `libs/common`    |
| `ml`       | ML / Data team  | `domains/ml`, `libs/common`                       |
| `infra`    | Infra / Platform| `domains/infra`, `libs/common`, `.github`         |
| `jvm`      | JVM team        | `domains/jvm`, `libs/common`                      |

### Add a directory to an existing profile

Edit the relevant `common/sparo-profiles/<name>.json` and add the path to
`includeFolders`.  Commit the change — your teammates pick it up automatically
when they next run `sparo checkout`.

### Create a new profile

```bash
# Writes a template to common/sparo-profiles/my-team.json
sparo init-profile --profile my-team
```

Edit the created file to fill in `includeFolders`, then:
1. Add the profile name to the `options` list in `.github/workflows/profile.yml`.
2. Add it to the matrix `fromJson` arrays in the same file.
3. Update the table above.

---

## 1. Developer workstation — Sparo profile checkout

Install Sparo once (globally):

```bash
npm install -g sparo
```

### Fresh clone

```bash
git clone --filter=blob:none --no-checkout https://github.com/org/monorepo.git
cd monorepo
git sparse-checkout init --cone
git sparse-checkout set scripts .github toolchains common/sparo-profiles
git checkout
sparo checkout --profile frontend
```

Or use the helper script (handles all steps):

```bash
./scripts/sparse-checkout.sh --new-clone frontend https://github.com/org/monorepo.git
```

### Switch profile on an existing clone

```bash
./scripts/sparse-checkout.sh frontend
# or directly:
sparo checkout --profile frontend
```

### List available profiles

```bash
./scripts/sparse-checkout.sh --list
# or:
sparo list-profiles
```

### Combine profiles (e.g. touching a shared library)

```bash
# Check out everything the frontend AND backend teams need
sparo checkout --profile frontend
sparo checkout --add-profile backend
```

---

## 2. Pull request CI — affected targets only

**Workflow**: `.github/workflows/affected.yml`
**Trigger**: every PR against `main` / `master`

Dynamically computes the minimum set of directories to checkout based on what
the PR actually changed.  Sparo static profiles do not fit this model (the
affected dirs are computed at runtime), so this workflow uses raw
`git sparse-checkout` commands for Phase 2 expansion.

```
Phase 1 — blobless clone + sparse cone (scripts/ .github/ toolchains/).
          Materialise ALL BUCK files via git cat-file (tiny Starlark text).
          Install Buck2.
          Run buck2 uquery rdeps(//..., changed-targets) — full graph view
          because all BUCK files are present.

Phase 2 — git sparse-checkout set <affected dirs>
          Install toolchains (Node / Python) only if needed.
          buck2 build / test (quality genrules included in build).
```

**Why not Sparo for Phase 2?**  The affected dirs are determined at runtime by
`buck2 uquery rdeps()`.  We could write a dynamic `affected.json` profile and
run `sparo checkout --profile affected`, but it adds overhead (jq / JSON
generation) with no benefit over a direct `git sparse-checkout set`.

---

## 3. Profile CI — full domain sweep

**Workflow**: `.github/workflows/profile.yml`
**Triggers**:
- `workflow_dispatch` — run any named profile on demand (dropdown in GitHub UI)
- `schedule` (nightly Mon–Fri 02:00 UTC) — all profiles run in parallel

Uses Sparo for checkout:

```
Phase 1 — blobless clone + cone including common/sparo-profiles/
           so profile JSON files are on disk before sparo runs.

Phase 2 — sparo checkout --profile <name>
           Sparo reads includeFolders from the JSON, generates cone patterns,
           and calls git sparse-checkout set internally.

          Install Buck2.
          Detect toolchains by reading profile JSON (jq) + filesystem checks.
          buck2 build //dir/... (covers all genrule quality targets too).
          buck2 test  //dir/...
```

### Run a profile manually

```bash
# From GitHub UI: Actions → Profile CI → Run workflow → pick profile

# From CLI:
gh workflow run profile.yml -f profile=frontend
```

### When to run a profile manually

| Situation | Recommended profile |
|-----------|---------------------|
| Before a release of the JS API | `frontend` |
| Investigating a nightly failure | the failing profile |
| After updating `libs/common` | `backend` + `frontend` (or both via dispatch) |
| Onboarding — verify your local setup builds | your team's profile |

---

## Cone mode

All sparse-checkout in this repo uses **cone mode** (the default since Git 2.37),
which restricts patterns to whole directories.  Sparo always uses cone mode.

```bash
git sparse-checkout list    # inspect active cone
git sparse-checkout reapply # reapply patterns after a merge
```

---

## Two-sentence summary

> **Sparo profiles** (`common/sparo-profiles/*.json`) define what each team needs locally and for nightly CI.  For PR CI, `buck2 uquery rdeps()` computes the minimum affected set dynamically — no profile needed.
