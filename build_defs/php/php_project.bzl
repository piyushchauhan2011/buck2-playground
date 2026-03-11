"""PHP/Laravel project macro for Composer-based packages.

Generates all standard quality + build + test targets from a single
php_project() call. Uses the PHP toolchain when available. Produces:
  <name>_lint        genrule  Laravel Pint --test
  <name>_fmt         genrule  Pint --test (format check)
  <name>_typecheck   genrule  PHPStan
  <name>_sast        genrule  SAST placeholder
  <name>_build       genrule  composer install + php -r "require autoload"
  <name>_test        sh_test  vendor/bin/phpunit
"""

load("@prelude//:native.bzl", "native")
load(":php_test.bzl", "php_test")

def php_project(
        name,
        package_dir,
        srcs,
        build_deps = [],
        use_hermetic = False,
        visibility = ["PUBLIC"]):
    """Generate lint / fmt / typecheck / build / test / sast targets.

    Args:
        name:        Base name shared by all generated targets.
        package_dir: Path to the package relative to the repo root,
                     e.g. "domains/api/php".
        srcs:        Source + test PHP files and config (glob recommended).
        build_deps:  Targets that must finish before _build and _typecheck run,
                     e.g. ["//libs/php-common:php_common_build"].
        use_hermetic: If True, use hermetic PHP (toolchains//:php_hermetic) and
                      Composer for reproducible builds on Linux/macOS.
        visibility:  Buck visibility list, default PUBLIC.
    """
    _php = "$(exe toolchains//:php_hermetic)" if use_hermetic else "php"
    _composer_cmd = _php + " $(location //third_party/php:composer_phar)" if use_hermetic else "composer"
    _prefix = 'repo=\$(git rev-parse --show-toplevel); out="$PWD/$OUT"; cd "$repo/' + package_dir + '"; '
    _dep_guard = "; ".join([
        "_dep=$(location {})".format(d)
        for d in build_deps
    ]) if build_deps else ":"

    _build_srcs = srcs + (["//third_party/php:composer_phar"] if use_hermetic else [])

    native.genrule(
        name = name + "_lint",
        out = name + "_lint.txt",
        srcs = srcs,
        cmd = _prefix + "vendor/bin/pint --test && echo LINT_PASS > \"$out\"",
        visibility = visibility,
    )

    native.genrule(
        name = name + "_fmt",
        out = name + "_fmt.txt",
        srcs = srcs,
        cmd = _prefix + "vendor/bin/pint --test && echo FMT_PASS > \"$out\"",
        visibility = visibility,
    )

    native.genrule(
        name = name + "_typecheck",
        out = name + "_typecheck.txt",
        srcs = srcs,
        cmd = _prefix + _dep_guard + "; vendor/bin/phpstan analyse --no-progress && echo TYPECHECK_PASS > \"$out\"",
        visibility = visibility,
    )

    native.genrule(
        name = name + "_sast",
        out = name + "_sast.txt",
        srcs = srcs,
        cmd = "echo SAST_PASS > $OUT",
        visibility = visibility,
    )

    native.genrule(
        name = name + "_build",
        out = name + "_build.txt",
        srcs = _build_srcs,
        cmd = _prefix + _dep_guard + "; [ -d vendor ] || " + _composer_cmd + " install --no-interaction --prefer-dist; " + _php + " -r \"require 'vendor/autoload.php';\" && echo BUILD_PASS > \"$out\"",
        visibility = visibility,
    )

    php_test(
        name = name + "_test",
        package_dir = package_dir,
        srcs = srcs,
        deps = build_deps,
        visibility = visibility,
    )
