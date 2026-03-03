# Phase 1: Buck2 Core Foundations (Week 1)

## Mental Model

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Target** | A buildable unit with a label (e.g., `//domains/api:server`). Defined in `BUCK` files. |
| **Provider** | Data passed between rules (e.g., `DefaultInfo` carries artifacts; `RunInfo` carries run command). |
| **Toolchain** | Platform-specific tools (compiler, linker) resolved at build time. |
| **Configuration** | Platform/target constraints that affect how rules resolve (e.g., linux-x86 vs mac-arm). |
| **Target Pattern** | Globs like `//...`, `//domains/...`, `//domains/api:server`. |
| **Query Graph** | Directed graph of targets and their dependencies. |

### Configured Graph vs Action Graph

- **Configured Graph**: Targets after configuration is applied (platforms, selects resolved). Use `cquery`.
- **Action Graph**: Low-level actions (compile, link, run) that produce outputs. Use `aquery`.

## Daily Exercises

### Day 1: Build and Run

```bash
# Build a single target
buck2 build //:hello_world

# Inspect output
cat buck-out/v2/gen/root/hello_world/out.txt
```

### Day 2: Query Dependencies

```bash
# List all dependencies of a target
buck2 cquery "deps(//:hello_world)" --output-all-attributes

# List reverse dependencies (what depends on X)
buck2 cquery "rdeps(//..., //:hello_world)"
```

### Day 3: Target Patterns

```bash
# Match all targets under a path
buck2 cquery "//domains/..." --output full

# Filter by rule kind
buck2 cquery "kind(genrule, //...)"
```

### Day 4: Tests and testsof

```bash
# Find tests for a target
buck2 cquery "testsof(//domains/api/...)" --output full

# Build and run tests
buck2 test //domains/api/...
```

### Day 5: Action Graph (aquery)

```bash
# Inspect actions for a build
buck2 aquery "deps(//domains/api:server)" --output json

# Get commands that would run
buck2 aquery "//domains/api:server" --output-attribute cmd
```

## Checkpoint

By end of Week 1 you should:

- [ ] Read and write basic `BUCK` files
- [ ] Run `buck2 build`, `buck2 test`, `buck2 run`
- [ ] Use `cquery` with `deps()`, `rdeps()`, `kind()`, `testsof()`
- [ ] Distinguish configured graph (cquery) from action graph (aquery)
