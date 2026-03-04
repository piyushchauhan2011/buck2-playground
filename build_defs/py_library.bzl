"""Python quality macro for lint / fmt / typecheck / sast targets.

Quality targets are always genrules: they invoke external tools (ruff, mypy,
bandit) that operate on source files and live outside Buck2's build graph.
py_quality() eliminates copy-paste across BUCK files.

Buck2 genrules run from the project root (via env --chdir), so cmds
reference package_dir directly — no sandbox escapes needed.
"""

def py_quality(
        name,
        package_dir,
        srcs,
        visibility = ["PUBLIC"]):
    """Generate lint / fmt / typecheck / sast quality targets.

    Args:
        name:        Base name prefix (e.g. "api_python").
        package_dir: Package path relative to repo root (e.g. "domains/api/python").
        srcs:        Python source + test files (glob recommended).
        visibility:  Buck visibility list, default PUBLIC.
    """

    genrule(
        name = name + "_lint",
        out = name + "_lint.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; ' +
            'cd {dir} && python -m ruff check src/ tests/ && echo LINT_PASS > "$out"'
        ).format(dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_fmt",
        out = name + "_fmt.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; ' +
            'cd {dir} && python -m ruff format --check src/ tests/ && echo FMT_PASS > "$out"'
        ).format(dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_typecheck",
        out = name + "_typecheck.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; ' +
            'cd {dir} && python -m mypy src/ && echo TYPECHECK_PASS > "$out"'
        ).format(dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_sast",
        out = name + "_sast.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; ' +
            'cd {dir} && python -m bandit -r src/ -ll && echo SAST_PASS > "$out"'
        ).format(dir = package_dir),
        visibility = visibility,
    )
