# Buck2 Polyglot Monorepo Tutorial

A learning repo for Buck2 with a multi-language monorepo: Rust, Python, JavaScript, Go, Java, Kotlin, Scala, C++, Shell, Lua.

## Quick Start

```bash
buck2 build //domains/...
buck2 test //domains/api/rust:api_rust_test
```

## Layout

- `domains/` - Domain-specific services (api, backend, ml, infra, jvm)
- `libs/` - Shared libraries
- `exercises/` - Phase 1 foundations exercises
- `scripts/` - PHP artifact build (release); monorepo tooling in `libs/monorepo-tooling-rust`
- `docs/` - Curriculum, playbooks, interview prep

## Features

- **Quality targets**: lint, fmt, sast per language (see `docs/quality-convention.md`)
- **Affected CI**: `libs/monorepo-tooling-rust` (Rust) + `.github/workflows/affected.yml`
- **Sparse checkout**: `./libs/monorepo-tooling-rust/target/release/monorepo-tooling sparse-checkout apply <profile>`
- **Perf tuning**: `docs/perf-tuning.md`
- **Interview prep**: `docs/interview-prep.md`

## Learning Path

1. `docs/curriculum/01-foundations-week1.md` - Core concepts
2. `docs/curriculum/02-exercise-targets.md` - Query exercises
3. `docs/onboarding/template-per-language.md` - Add new languages
