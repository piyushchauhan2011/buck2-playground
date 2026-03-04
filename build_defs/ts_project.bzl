"""TypeScript project macro for pnpm workspaces.

Generates all standard quality + build targets for a TypeScript package
from a single ts_project() call, eliminating 50+ lines of boilerplate
per BUCK file.

Targets produced (all named <name>_<suffix>):
  <name>_lint        genrule  ESLint, cached on src change
  <name>_fmt         genrule  Prettier --check, cached on src change
  <name>_typecheck   genrule  tsc --noEmit, cached on src change
  <name>_build       genrule  tsc -p tsconfig.build.json, cached on src change
  <name>_vitest      sh_test  vitest run (executed by `buck2 test`)
  <name>_sast        genrule  SAST placeholder (extend with semgrep/snyk)

SANDBOX NOTE
------------
All genrule cmds shell out via `git rev-parse --show-toplevel` to run pnpm
from the real workspace root where node_modules exists.  This bypasses Buck2's
hermetic sandbox, which means these targets cannot run on remote-execution
workers.  The long-term path to full hermeticity is to declare node_modules as
Buck targets backed by a JS toolchain — out of scope for a pnpm workspace.
`$(location dep)` variables are used for build-order deps (the location string
forces Buck to build the dep; the variable itself is intentionally unused).
"""

def ts_project(
        name,
        package_dir,
        srcs,
        build_deps = [],
        visibility = ["PUBLIC"]):
    """Generate lint / fmt / typecheck / build / test / sast targets.

    Args:
        name:        Base name shared by all generated targets.
        package_dir: Path to the package relative to the repo root,
                     e.g. "domains/api/js" or "libs/common".
        srcs:        Source + test TypeScript files (glob recommended).
        build_deps:  Targets that must finish before <name>_build runs,
                     typically a upstream library's _build target, e.g.
                     ["//libs/common:common_build"].  Also applied to
                     <name>_typecheck so composite project references resolve.
        visibility:  Buck visibility list, default PUBLIC.
    """
    _repo = "\\$(git rev-parse --show-toplevel)"

    # Build-order dep fragment: assign $(location X) to a throwaway variable
    # so Buck records the edge without requiring the output path in the cmd.
    _dep_guard = "; ".join([
        "_dep=$(location {})".format(d)
        for d in build_deps
    ]) if build_deps else ":"

    genrule(
        name = name + "_lint",
        out = name + "_lint.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; repo={repo}; ' +
            'pnpm run --dir "$repo/{dir}" lint && echo LINT_PASS > "$out"'
        ).format(repo = _repo, dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_fmt",
        out = name + "_fmt.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; repo={repo}; ' +
            'pnpm run --dir "$repo/{dir}" "format:check" && echo FMT_PASS > "$out"'
        ).format(repo = _repo, dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_typecheck",
        out = name + "_typecheck.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; {deps}; repo={repo}; ' +
            'pnpm run --dir "$repo/{dir}" typecheck && echo TYPECHECK_PASS > "$out"'
        ).format(deps = _dep_guard, repo = _repo, dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_build",
        out = name + "_build.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; {deps}; repo={repo}; ' +
            'pnpm run --dir "$repo/{dir}" build && echo BUILD_PASS > "$out"'
        ).format(deps = _dep_guard, repo = _repo, dir = package_dir),
        visibility = visibility,
    )

    sh_test(
        name = name + "_vitest",
        test = "scripts/run_vitest.sh",
        resources = srcs,
        visibility = visibility,
    )

    genrule(
        name = name + "_sast",
        out = name + "_sast.txt",
        srcs = srcs,
        cmd = "echo SAST_PASS > $OUT",
        visibility = visibility,
    )
