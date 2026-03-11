"""PHP toolchain for Buck2 monorepo tooling.

Provides PhpToolchainInfo and system_php_toolchain for hermetic or
system PHP builds. Used by php_library, php_binary, php_test, and
quality rules (lint, fmt, typecheck, sast).
"""

PhpToolchainInfo = provider(
    fields = {
        "interpreter": provider_field(RunInfo),
        "composer": provider_field(RunInfo | None, default = None),
        "pint": provider_field(RunInfo | None, default = None),
        "phpstan": provider_field(RunInfo | None, default = None),
        "phpunit": provider_field(RunInfo | None, default = None),
        "version": provider_field(str, default = "8.4"),
    },
)

_INTERPRETER = select({
    "DEFAULT": "php",
    "config//os:windows": "php.exe",
})

def _system_php_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    interpreter = ctx.attrs.interpreter
    if isinstance(interpreter, str):
        interpreter_run_info = RunInfo(args = [interpreter])
    else:
        interpreter_run_info = interpreter[RunInfo]

    composer_run_info = None
    if ctx.attrs.composer:
        composer_run_info = ctx.attrs.composer[RunInfo]

    pint_run_info = None
    if ctx.attrs.pint:
        pint_run_info = ctx.attrs.pint[RunInfo]

    phpstan_run_info = None
    if ctx.attrs.phpstan:
        phpstan_run_info = ctx.attrs.phpstan[RunInfo]

    phpunit_run_info = None
    if ctx.attrs.phpunit:
        phpunit_run_info = ctx.attrs.phpunit[RunInfo]

    return [
        DefaultInfo(),
        PhpToolchainInfo(
            interpreter = interpreter_run_info,
            composer = composer_run_info,
            pint = pint_run_info,
            phpstan = phpstan_run_info,
            phpunit = phpunit_run_info,
            version = ctx.attrs.version,
        ),
    ]

system_php_toolchain = rule(
    impl = _system_php_toolchain_impl,
    attrs = {
        "composer": attrs.option(attrs.dep(providers = [RunInfo]), default = None),
        "interpreter": attrs.one_of(
            attrs.string(),
            attrs.dep(providers = [RunInfo]),
        ),
        "phpstan": attrs.option(attrs.dep(providers = [RunInfo]), default = None),
        "phpunit": attrs.option(attrs.dep(providers = [RunInfo]), default = None),
        "pint": attrs.option(attrs.dep(providers = [RunInfo]), default = None),
        "version": attrs.string(default = "8.4"),
    },
    is_toolchain_rule = True,
)
