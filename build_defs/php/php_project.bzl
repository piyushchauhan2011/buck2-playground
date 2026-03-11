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
        hermetic_in_ci = True,  # Use hermetic in CI (CI/GITHUB_ACTIONS), system locally
        visibility = ["PUBLIC"]):
    """Generate lint / fmt / typecheck / build / test / sast targets.

    Args:
        name:           Base name shared by all generated targets.
        package_dir:    Path to the package relative to the repo root,
                        e.g. "domains/api/php".
        srcs:           Source + test PHP files and config (glob recommended).
        build_deps:     Targets that must finish before _build and _typecheck run,
                        e.g. ["//libs/php-common:php_common_build"].
        use_hermetic:   If True, always use hermetic PHP and Composer.
        hermetic_in_ci: If True (default), use hermetic in CI (CI/GITHUB_ACTIONS),
                        system PHP locally. Requires hermetic deps for _build.
        visibility:     Buck visibility list, default PUBLIC.
    """
    _use_hermetic = use_hermetic or hermetic_in_ci
    # Resolve hermetic paths to absolute before cd; $(exe)/$(location) are relative to genrule cwd (srcs)
    _php = "$(exe //third_party/php:php_hermetic)" if _use_hermetic else "php"
    _composer_loc = "$(location //third_party/php:composer_phar)" if _use_hermetic else None
    # Use python to resolve relative paths to absolute (avoids $(dirname) escaping issues)
    _resolve = (
        "php_exe=" + _php + "; php_abs=\\$(python3 -c \"import os; print(os.path.abspath('$php_exe'))\"); "
        + "composer_exe=" + _composer_loc + "; composer_abs=\\$(python3 -c \"import os; print(os.path.abspath('$composer_exe'))\"); "
    ) if _use_hermetic else ""
    _composer_cmd = '"$php_abs" "$composer_abs"' if use_hermetic else "composer"
    _php_run = '"$php_abs"' if use_hermetic else "php"
    _prefix = (
        (_resolve if use_hermetic else "")
        + 'repo=\\$(git rev-parse --show-toplevel); out="$PWD/$OUT"; cd "$repo/' + package_dir + '"; '
    )
    _dep_guard = "; ".join([
        "_dep=$(location {})".format(d)
        for d in build_deps
    ]) if build_deps else ":"

    # hermetic_in_ci: runtime check; use_hermetic: always hermetic
    if hermetic_in_ci and not use_hermetic:
        _build_resolve = (
            "if [ -n \"${CI:-}\" ] || [ -n \"${GITHUB_ACTIONS:-}\" ]; then "
            + "php_exe=" + _php + "; php_abs=\\$(python3 -c \"import os; print(os.path.abspath('$php_exe'))\"); "
            + "composer_exe=" + _composer_loc + "; composer_abs=\\$(python3 -c \"import os; print(os.path.abspath('$composer_exe'))\"); "
            + "composer_cmd=\"$php_abs $composer_abs\"; php_cmd=\"$php_abs\"; "
            + "else composer_cmd=composer; php_cmd=php; fi; "
        )
        _build_composer_cmd = '"$composer_cmd"'
        _build_php_run = '"$php_cmd"'
    else:
        _build_resolve = _resolve if use_hermetic else ""
        _build_composer_cmd = _composer_cmd if use_hermetic else "composer"
        _build_php_run = _php_run if use_hermetic else "php"

    _build_prefix = (
        (_build_resolve if (hermetic_in_ci and not use_hermetic) else (_resolve if use_hermetic else ""))
        + 'repo=\\$(git rev-parse --show-toplevel); out="$PWD/$OUT"; cd "$repo/' + package_dir + '"; '
    )

    _build_srcs = srcs + (["//third_party/php:composer_phar"] if _use_hermetic else [])

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
        cmd = _build_prefix + _dep_guard + "; [ -d vendor ] || " + _build_composer_cmd + " install --no-interaction --prefer-dist; " + _build_php_run + " -r \"require 'vendor/autoload.php';\" && echo BUILD_PASS > \"$out\"",
        visibility = visibility,
    )

    php_test(
        name = name + "_test",
        package_dir = package_dir,
        srcs = srcs,
        deps = build_deps,
        visibility = visibility,
    )
