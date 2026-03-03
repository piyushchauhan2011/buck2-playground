# Buck2 Interview Prep

## Core Concepts

### Configured Graph vs Action Graph

- **Configured graph**: Targets after configuration (platform, selects resolved). Use `cquery`. Answers "what will be built?"
- **Action graph**: Low-level actions (compile, link, run). Use `aquery`. Answers "what commands run?"

### Affected-Target Computation

1. Get changed files from `git diff`
2. Map to owning packages (nearest BUCK file)
3. `cquery "kind(genrule, //pkg/...)"` for owned targets
4. `rdeps(//..., target)` for impacted consumers
5. `testsof(...)` for impacted tests

### Cache Economics

- **Remote cache** reduces wall-clock by reusing outputs from other machines
- **Cache key** = hash(inputs, command, platform). Non-deterministic inputs (timestamps, hostname) cause misses
- **Hermetic actions**: all inputs declared, no side effects, deterministic outputs

## System Design Scenarios

### "Monorepo at 10x scale"

- Affected-target CI: only build/test what changed
- Remote cache + RE: parallel, cached builds
- Sparse checkout: devs clone only their domain
- Shard CI by domain or use dynamic sharding via cquery

### "Flaky selective tests"

- Fallback rule: if ownership mapping fails, run broader scope
- Deterministic test isolation: no shared state, stable ordering
- Retry with full test suite on main/release branches

### "Cache miss explosion after toolchain upgrade"

- Pin toolchain versions in .buckconfig or toolchain rules
- Use digest-stable paths for tools
- Blue-green toolchain rollout: new version = new cache namespace

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Build works locally, fails in CI | Non-hermetic inputs | Audit `cmd` for env, host paths |
| Slow cold builds | No remote cache | Enable action cache |
| Affected CI runs too much | Overbroad package mapping | Use `owner()` for file→target |
| Sparse checkout breaks build | Missing deps outside cone | Add dep paths to profile |
