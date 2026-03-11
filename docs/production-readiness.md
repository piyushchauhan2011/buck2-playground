# Production Readiness Gaps

This document lists known gaps compared to production monorepos at scale (e.g. Google, Meta, Microsoft). These are documented for future consideration; no implementation is implied.

The repo already has strong foundations: sparse checkouts, affected CI, profile CI, and release artifacts. See [ci-affected-design.md](ci-affected-design.md), [deploy.md](deploy.md), and [sparse-checkout-playbook.md](sparse-checkout-playbook.md).

---

## 1. Build Caching

**Current state:** Each CI run does a cold build.

**Gap:** No remote cache configured. Buck2 supports remote caching via Bazel RE API (EngFlow, BuildBarn, BuildBuddy).

**Recommendation:** Add optional Buck2 remote cache in `.buckconfig`. Use `actions/cache` for Buck2 local cache directory as a fallback.

---

## 2. Code Ownership and Security

**Current state:** No CODEOWNERS or branch protection policies.

**Gap:** No automated code review assignment or approval requirements.

**Recommendation:**
- Add `.github/CODEOWNERS` mapping paths to teams
- Document branch protection (require PR reviews, status checks)
- Consider two-approval rule for critical paths if needed

---

## 3. Observability and CI Metrics

**Current state:** No pipeline metrics, timing, or failure tracking.

**Gap:** Hard to answer "how long does CI take?" or "which jobs fail most often?"

**Recommendation:**
- Add job-level timing; log duration in a summary step
- Optional: GitHub Actions job summary with affected targets count, sparse dirs count, per-job duration
- Consider lightweight tracing (e.g. OpenTelemetry) for cross-run analytics

---

## 4. Release and Versioning

**Current state:** Manual release via branches/tags; app registry hardcoded in `build_php_artifact.sh` and `release.yml`.

**Gap:** Adding a new app requires edits in multiple places; no changelog automation.

**Recommendation:**
- Extract app registry to a single source of truth (e.g. `common/release-apps.json`)
- Optional: Add release-please or similar for automated changelog and version bumps

---

## 5. Dependency and Security Scanning

**Gap:** No automated dependency updates or vulnerability scanning.

**Recommendation:**
- Add Dependabot or Renovate for `package.json`, `composer.json`, `requirements*.txt`
- Add `composer audit` and `pnpm audit` to quality jobs
- Optional: SAST (e.g. CodeQL) if not covered by existing quality targets

---

## 6. Documentation and Runbooks

**Current state:** Good docs for CI, deploy, and sparse checkout.

**Recommendation:**
- Document rollback procedure (revert tag, redeploy previous artifact) in `docs/deploy.md`
- Add runbooks for common operational tasks
