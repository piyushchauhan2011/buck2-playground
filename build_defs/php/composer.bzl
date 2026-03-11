"""Composer / vendor rules for hermetic PHP builds.

Provides composer_install genrule that runs composer install and
outputs vendor/ as a build artifact. Used by php_binary and php_test
for hermetic execution.
"""

load("@prelude//:native.bzl", "native")

def composer_install(
        name,
        package_dir,
        composer_json = "composer.json",
        composer_lock = "composer.lock",
        no_dev = False,
        visibility = ["PUBLIC"]):
    """Run composer install and output vendor/ as build artifact.

    Args:
        name: Target name (e.g. "vendor").
        package_dir: Path to package relative to repo root.
        composer_json: Path to composer.json within package.
        composer_lock: Path to composer.lock within package.
        no_dev: If True, use --no-dev (for production).
        visibility: Buck visibility.
    """
    json_path = package_dir + "/" + composer_json
    lock_path = package_dir + "/" + composer_lock
    no_dev_flag = "--no-dev" if no_dev else ""

    native.genrule(
        name = name,
        out = name + "_stamp.txt",
        srcs = [json_path, lock_path],
        cmd = (
            'repo=\\$(git rev-parse --show-toplevel); '
            'cd "$repo/' + package_dir + '" && '
            '[ -d vendor ] || composer install --no-interaction --prefer-dist ' + no_dev_flag + ' && '
            'echo COMPOSER_INSTALL_OK > "$OUT"'
        ),
        visibility = visibility,
    )
