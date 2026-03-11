"""PHP test rule for Buck2.

Runs PHPUnit tests. Uses package_dir to run from the project root
where vendor/ and phpunit.xml are located.
"""

load("@prelude//:native.bzl", "native")

def php_test(
        name,
        package_dir,
        test_script = "scripts/run_phpunit.sh",
        srcs = [],
        deps = [],
        visibility = ["PUBLIC"]):
    """Create a PHPUnit test target.

    Wraps sh_test to run PHPUnit from the package directory.
    Compatible with existing php_project() test targets.

    Args:
        name: Target name.
        package_dir: Path to package relative to repo root (e.g. "domains/api/php").
        test_script: Script that runs PHPUnit (default: scripts/run_phpunit.sh).
        srcs: Source files for the test (for cache invalidation).
        deps: Build deps that must complete before test runs.
        visibility: Buck visibility.
    """
    native.sh_test(
        name = name,
        test = test_script,
        resources = srcs,
        deps = deps,
        visibility = visibility,
    )
