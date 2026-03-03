# Affected CI Design

## Flow

1. **Changed files** from `git diff base..HEAD`
2. **Package mapping** - map each file to owning BUCK package (nearest parent with BUCK)
3. **Owned targets** - `cquery "kind(genrule, //pkg/...)"` (or `owner()` when available)
4. **Impacted targets** - `rdeps(//..., owned)` for reverse deps
5. **Impacted tests** - `filter('test', ...)` + `testsof(//pkg/...)`
6. **Quality targets** - `attrregexfilter(name, 'lint|fmt|sast', ...)`

## Query Patterns

```bash
# Affected packages for changed file
buck2 cquery "kind(genrule, //domains/api/...)"

# Reverse deps (impacted consumers)
buck2 cquery "rdeps(//..., //domains/api:api_rust)"

# Tests for targets
buck2 cquery "testsof(//domains/api/...)"

# Quality targets
buck2 cquery "attrregexfilter(name, 'lint|fmt|sast', //domains/api/...)"
```

## Fallback

If ownership mapping fails or returns empty, run broader validation (e.g. `//domains/...`).
