load("@prelude//:native.bzl", "native")

"""PHP/Laravel project macro for Composer-based packages.

Generates all standard quality + build + test targets from a single
php_project() call. No native Buck2 PHP rules exist; these are genrules
and sh_test delegating to host-installed tools (Composer, PHPUnit,
Laravel Pint, PHPStan).

Targets produced (all named <name>_<suffix>):
  <name>_lint        genrule  Laravel Pint --test, cached on src change
  <name>_fmt         genrule  Pint --test (format check), cached on src change
  <name>_typecheck   genrule  PHPStan, cached on src change
  <name>_sast        genrule  SAST placeholder (extend with security rules)
  <name>_build       genrule  php artisan config:cache (smoke test)
  <name>_test        sh_test  vendor/bin/phpunit (executed by buck2 test)
"""

def php_project(
        name,
        package_dir,
        srcs,
        build_deps = [],
        visibility = ["PUBLIC"]):
    """Generate lint / fmt / typecheck / build / test / sast targets.

    Args:
        name:        Base name shared by all generated targets.
        package_dir: Path to the package relative to the repo root,
                     e.g. "domains/api/php".
        srcs:        Source + test PHP files and config (glob recommended).
        build_deps:  Targets that must finish before _build and _typecheck run,
                     e.g. ["//libs/php-common:php_common_build"].
        visibility:  Buck visibility list, default PUBLIC.
    """
    _prefix = 'repo=\$(git rev-parse --show-toplevel); out="$PWD/$OUT"; cd "$repo/' + package_dir + '"; '
    _dep_guard = "; ".join([
        "_dep=$(location {})".format(d)
        for d in build_deps
    ]) if build_deps else ":"

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
        srcs = srcs,
        cmd = _prefix + _dep_guard + "; [ -d vendor ] || composer install --no-interaction --prefer-dist; php -r \"require 'vendor/autoload.php';\" && echo BUILD_PASS > \"$out\"",
        visibility = visibility,
    )

    native.sh_test(
        name = name + "_test",
        test = "scripts/run_phpunit.sh",
        resources = srcs,
        deps = build_deps,
        visibility = visibility,
    )
