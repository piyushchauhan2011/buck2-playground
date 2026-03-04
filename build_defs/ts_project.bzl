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

HERMETICITY
-----------
Buck2 genrules already run from the project root (via env --chdir).  Cmds
reference the package_dir directly — no sandbox escapes or git rev-parse.
$(location dep) variables force Buck to build upstream deps before this
target runs.  The hermetic Node.js binary from //third_party/node:node is
available for future use; quality commands currently delegate to pnpm which
resolves from the project root.
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
                     typically an upstream library's _build target, e.g.
                     ["//libs/common:common_build"].  Also applied to
                     <name>_typecheck so composite project references resolve.
        visibility:  Buck visibility list, default PUBLIC.
    """

    _dep_guard = "; ".join([
        "_dep=$(location {})".format(d)
        for d in build_deps
    ]) if build_deps else ":"

    genrule(
        name = name + "_lint",
        out = name + "_lint.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; ' +
            'pnpm run --dir {dir} lint && echo LINT_PASS > "$out"'
        ).format(dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_fmt",
        out = name + "_fmt.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; ' +
            'pnpm run --dir {dir} "format:check" && echo FMT_PASS > "$out"'
        ).format(dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_typecheck",
        out = name + "_typecheck.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; {deps}; ' +
            'pnpm run --dir {dir} typecheck && echo TYPECHECK_PASS > "$out"'
        ).format(deps = _dep_guard, dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_build",
        out = name + "_build.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; {deps}; ' +
            'pnpm run --dir {dir} build && echo BUILD_PASS > "$out"'
        ).format(deps = _dep_guard, dir = package_dir),
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
