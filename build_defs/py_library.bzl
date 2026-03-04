"""Python library macro for FastAPI / standard Python packages.

Provides two things:

1.  py_quality()  — generates the four quality genrule targets (lint, fmt,
    typecheck, sast) for a Python package, eliminating copy-paste across BUCK
    files.  Quality targets always use genrules because they invoke external
    tools (ruff, mypy, bandit) that live outside Buck2's build graph.

2.  Guidance on native python_library / python_binary / python_test rules
    (used directly in BUCK files — see domains/api/python/BUCK).

NATIVE RULES vs GENRULE
------------------------
Buck2's prelude ships real python_library / python_binary / python_test rules:

  python_library   models a importable Python package; output is included in
                   the .pex archive built by python_binary.
  python_binary    produces a self-contained .pex executable.
  python_test      runs tests through Buck2's test infrastructure (supports
                   `buck2 test` result streaming, --xml, retry logic, etc.).

THIRD-PARTY DEPS LIMITATION
-----------------------------
Buck2 Python rules track deps as Buck targets.  Third-party packages (fastapi,
pytest, ruff, …) must be declared as prebuilt_python_library targets or managed
via a pip-integration tool.  With system_demo_toolchains() the interpreter is
the system/venv Python, so packages installed in the venv ARE importable at
runtime — but Buck has no visibility into them and cannot cache-invalidate on
version changes.

For production use, replace system_demo_toolchains() with a hermetic Python
toolchain and declare third-party deps explicitly (e.g. via rules_python's
pip_parse or a vendored third_party/python/BUCK).
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
    _repo = "\\$(git rev-parse --show-toplevel)"

    genrule(
        name = name + "_lint",
        out = name + "_lint.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; repo={repo}; ' +
            'cd "$repo/{dir}" && python -m ruff check src/ tests/ && echo LINT_PASS > "$out"'
        ).format(repo = _repo, dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_fmt",
        out = name + "_fmt.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; repo={repo}; ' +
            'cd "$repo/{dir}" && python -m ruff format --check src/ tests/ && echo FMT_PASS > "$out"'
        ).format(repo = _repo, dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_typecheck",
        out = name + "_typecheck.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; repo={repo}; ' +
            'cd "$repo/{dir}" && python -m mypy src/ && echo TYPECHECK_PASS > "$out"'
        ).format(repo = _repo, dir = package_dir),
        visibility = visibility,
    )

    genrule(
        name = name + "_sast",
        out = name + "_sast.txt",
        srcs = srcs,
        cmd = (
            'out="$PWD/$OUT"; repo={repo}; ' +
            'cd "$repo/{dir}" && python -m bandit -r src/ -ll && echo SAST_PASS > "$out"'
        ).format(repo = _repo, dir = package_dir),
        visibility = visibility,
    )
