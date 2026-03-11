"""PHP library rule for Buck2.

Represents a PHP package (sources + deps). Used by Laravel apps and
shared libs (e.g. libs/php-common). Provides PhpLibraryInfo for
dependency resolution.
"""

load("@prelude//:paths.bzl", "paths")
load("@prelude//utils:utils.bzl", "from_named_set")

PhpLibraryInfo = provider(
    fields = {
        "sources": provider_field(list[Artifact]),
        "source_dirs": provider_field(dict[str, Artifact]),
    },
)

def _gather_sources(raw_deps: list[Dependency]) -> list[Artifact]:
    """Collect all PHP sources from transitive deps."""
    sources = []
    for dep in raw_deps:
        if PhpLibraryInfo in dep:
            info = dep[PhpLibraryInfo]
            sources.extend(info.sources)
    return sources

def _php_library_impl(ctx: AnalysisContext) -> list[Provider]:
    srcs = from_named_set(ctx.attrs.srcs)
    raw_deps = ctx.attrs.deps

    dep_sources = _gather_sources(raw_deps)
    all_sources = list(srcs.values()) + dep_sources

    source_dirs = {}
    for name, artifact in srcs.items():
        dirname = paths.dirname(name)
        if dirname and dirname not in source_dirs:
            source_dirs[dirname] = artifact

    library_info = PhpLibraryInfo(
        sources = list(srcs.values()),
        source_dirs = source_dirs,
    )

    outputs = list(srcs.values()) if srcs else []
    return [
        library_info,
        DefaultInfo(
            default_output = outputs[0] if outputs else None,
            other_outputs = outputs,
        ),
    ]

php_library = rule(
    impl = _php_library_impl,
    attrs = {
        "deps": attrs.list(attrs.dep(), default = []),
        "srcs": attrs.named_set(attrs.source(), sorted = True),
    },
)
