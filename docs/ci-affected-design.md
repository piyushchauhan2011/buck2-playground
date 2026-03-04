# Affected CI Design

## Flow

1. **Changed files** — `git diff base..HEAD`
2. **Package mapping** — walk up from each changed file to the nearest parent directory containing a `BUCK` file
3. **Owned targets** — `uquery "kind('genrule|sh_test', //pkg/...)"` for each affected package
4. **Impacted targets** — `uquery "rdeps(//..., set(...))"` expands to all transitive reverse-dependencies across the whole repo (safe because all BUCK files are materialised via `git cat-file` before this step)
5. **Classify targets** — split the impacted set into build, test, and quality buckets using `filter()` and `attrregexfilter()`

## Why `uquery` and not `cquery`

`uquery` reads only BUCK file dependency edges and does not validate that source files exist on disk.  After the sparse-checkout expansion, source files for *directly* changed packages are present, but consumer packages pulled in via `rdeps()` may only have their BUCK file on disk.  `cquery` silently drops those packages; `uquery` handles them correctly.

## Query patterns

```bash
# Targets in an affected package (genrules + sh_test targets)
buck2 uquery "kind('genrule|sh_test', //domains/api/...)"

# Reverse deps — everything transitively impacted
buck2 uquery "rdeps(//..., set(//domains/api:api_python //libs/common:common_build))"

# Classify: test targets (name ends in _test or _vitest)
buck2 uquery "filter('(_test|_vitest)$', set(...))"

# Classify: quality targets (name ends in lint, fmt, sast, or typecheck)
buck2 uquery "attrregexfilter(name, '(lint|fmt|sast|typecheck)$', set(...))"
```

> **Note:** Buck2 uses Rust's regex crate, which does not support lookaheads,
> so negative lookahead patterns like `(?!...)` do not work.  Classification
> uses positive `filter()` / `attrregexfilter()` patterns instead.

## Fallback

If the package mapping returns nothing (e.g. a change only touches root-level config), `BUILD_TARGETS`, `TEST_TARGETS`, and `QUALITY_TARGETS` are exported as empty strings and the workflow skips the build/test/quality steps.
