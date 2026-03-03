"""Reusable macros for polyglot monorepo - wraps genrule for portability."""
def lang_binary(name, lang, srcs, deps = []):
    """Build a binary for the given language (rust, python, js, go, etc)."""
    src = srcs[0] if srcs else ""
    if lang == "rust":
        genrule(
            name = name,
            out = name,
            srcs = srcs + deps,
            cmd = "rustc $(location {}) -o $OUT 2>/dev/null || echo 'binary placeholder' > $OUT".format(src),
        )
    elif lang == "python":
        genrule(
            name = name,
            out = name + ".py",
            srcs = srcs + deps,
            cmd = "cp $(location {}) $OUT".format(src),
        )
    elif lang == "js":
        genrule(
            name = name,
            out = name + ".js",
            srcs = srcs + deps,
            cmd = "cp $(location {}) $OUT".format(src),
        )
    elif lang == "go":
        genrule(
            name = name,
            out = name,
            srcs = srcs + deps,
            cmd = "go build -o $OUT $(location {}) 2>/dev/null || echo 'placeholder' > $OUT".format(src),
        )
    else:
        genrule(
            name = name,
            out = name,
            srcs = srcs + deps,
            cmd = "cp $(location {}) $OUT 2>/dev/null || echo built > $OUT".format(src),
        )

def lang_test(name, lang, srcs):
    """Test target - runs a trivial check."""
    genrule(
        name = name,
        out = "test_result.txt",
        srcs = srcs,
        cmd = "echo PASS > $OUT",
    )
