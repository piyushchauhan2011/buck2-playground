# Language Onboarding Template

Use this template when adding a new language to the monorepo.

## 1. Create Domain Directory

```
domains/<domain>/<lang>/
  - main.<ext>   # entry point
  - BUCK         # build rules
```

## 2. BUCK File Pattern

```starlark
genrule(
    name = "<domain>_<lang>",
    out = "output",
    srcs = ["<lang>/main.<ext>"],
    cmd = "<compiler_or_runner> ... $(location <path>) ... $OUT",
)
```

## 3. Add Test Target

```starlark
genrule(
    name = "<domain>_<lang>_test",
    out = "test_result.txt",
    srcs = ["<lang>/*.<ext>"],
    cmd = "<test_runner> ... && echo PASS > $OUT",
)
```

## 4. Update Quality Targets

Add `#lint`, `#fmt`, `#sast` targets in `build_defs/quality.bzl` (see Phase 3).

## 5. Register in Affected CI

Ensure `scripts/affected_targets.sh` maps file extensions to owning targets.
