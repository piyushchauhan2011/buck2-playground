# PHP Toolchain and Rules

PHP toolchain and rules for Buck2 monorepo tooling, inspired by the [Buck2 Python prelude](https://github.com/facebook/buck2/tree/main/prelude/python). Supports build, test, quality, and deploy for PHP Laravel apps and shared PHP libs.

## Overview

| Component | Location | Purpose |
|-----------|----------|---------|
| Toolchain | `toolchains//:php` | PhpToolchainInfo (interpreter, composer, pint, phpstan, phpunit) |
| php_library | `build_defs/php:php_library.bzl` | Source aggregation, PhpLibraryInfo provider |
| php_binary | `build_defs/php:php_binary.bzl` | Runnable entry point (artisan, public/index.php) |
| php_test | `build_defs/php:php_test.bzl` | PHPUnit test wrapper (sh_test) |
| php_project | `build_defs/php:php_project.bzl` | Macro: lint, fmt, typecheck, sast, build, test |

## Usage

### php_project (recommended)

Single macro for Composer-based packages:

```starlark
load("//build_defs:php_project.bzl", "php_project")

php_project(
    name = "api_php",
    package_dir = "domains/api/php",
    srcs = glob(["app/**/*.php", "config/**/*.php", "tests/**/*.php", ...]),
    build_deps = ["//libs/php-common:php_common_build"],
)
```

Produces: `api_php_lint`, `api_php_fmt`, `api_php_typecheck`, `api_php_sast`, `api_php_build`, `api_php_test`.

### php_library

For source-only libs or when you need PhpLibraryInfo:

```starlark
load("//build_defs/php:php_library.bzl", "php_library")

php_library(
    name = "php_common_lib",
    srcs = glob(["src/**/*.php"]),
    deps = [],
)
```

### php_binary

Runnable Laravel artisan or entry point:

```starlark
load("//build_defs/php:php_binary.bzl", "php_binary")

php_binary(
    name = "artisan",
    main = "artisan",
    package_dir = "domains/api/php",
    deps = ["//libs/php-common:php_common_build"],
)
```

Run: `buck2 run //domains/api/php:artisan -- serve`

## Toolchain

The PHP toolchain (`toolchains//:php`) uses system PHP by default.

### Hermetic builds (Linux/macOS)

For reproducible builds that download PHP and Composer for the correct OS:

1. **Hermetic PHP**: `build_defs/php/remote_toolchain.bzl` provides `remote_php_toolchain()` which downloads [static-php-cli](https://github.com/crazywhalecc/static-php-cli) binaries (Linux x86_64/arm64, macOS x86_64/arm64).

2. **Hermetic Composer**: `third_party/php:composer_phar` downloads composer.phar (Composer 2.9.5).

3. **Enable hermetic** in `toolchains/BUCK`:
   ```starlark
   load("@root//build_defs/php:remote_toolchain.bzl", "remote_php_toolchain")
   remote_php_toolchain(name = "php")
   ```

4. **Use in php_project**:
   ```starlark
   php_project(..., use_hermetic = True)   # always hermetic
   php_project(..., hermetic_in_ci = True)  # hermetic in CI only (default)
   ```

Note: `hermetic_in_ci=True` (default) uses hermetic PHP in CI (`CI` or `GITHUB_ACTIONS` env set), system PHP locally. `use_hermetic=True` forces hermetic everywhere. The PHP archive (common build 8.2.18, openssl) lives in `third_party/php`.

## Quality Convention

Aligns with [quality-convention.md](quality-convention.md):

| Suffix | Tool | Target |
|--------|------|--------|
| _lint | Laravel Pint | `*_lint` |
| _fmt | Laravel Pint | `*_fmt` |
| _typecheck | PHPStan | `*_typecheck` |
| _sast | (placeholder) | `*_sast` |

## Deployment

The [release.yml](../.github/workflows/release.yml) workflow builds PHP artifacts via `scripts/build_php_artifact.sh`. The `php_binary` output can be integrated with the artifact script for deployment.
