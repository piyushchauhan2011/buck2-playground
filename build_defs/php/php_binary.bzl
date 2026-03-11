"""PHP binary rule for Buck2.

Creates a runnable entry point (e.g. artisan, public/index.php).
For Laravel apps, runs from package_dir with vendor/ available.
"""

load(":toolchain.bzl", "PhpToolchainInfo")

def _php_binary_impl(ctx: AnalysisContext) -> list[Provider]:
    toolchain = ctx.attrs._php_toolchain[PhpToolchainInfo]
    main = ctx.attrs.main
    package_dir = ctx.attrs.package_dir or ctx.label.package

    script_content = """#!/usr/bin/env bash
set -euo pipefail
REPO="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO/{package_dir}"
exec php {main} "$@"
""".format(package_dir = package_dir, main = main)

    script = ctx.actions.write("run_php.sh", script_content, is_executable = True)

    run_args = cmd_args([script])
    run_args.add("--")

    return [
        DefaultInfo(default_output = script),
        RunInfo(args = run_args),
    ]

php_binary = rule(
    impl = _php_binary_impl,
    attrs = {
        "deps": attrs.list(attrs.dep(), default = []),
        "main": attrs.string(),
        "package_dir": attrs.option(attrs.string(), default = None),
        "_php_toolchain": attrs.toolchain_dep(default = "toolchains//:php", providers = [PhpToolchainInfo]),
    },
)
