"""Hermetic PHP toolchain via static-php-cli and Composer.

Downloads PHP and Composer for the correct OS/CPU. Use remote_php_toolchain()
in toolchains/BUCK for hermetic builds on Linux runners and macOS.
"""

load("@prelude//:prelude.bzl", "native")
load(":toolchain.bzl", "system_php_toolchain")

# static-php-cli v2.8.2 - standalone PHP binaries from
# https://github.com/crazywhalecc/static-php-cli/releases
# DEFAULT -> linux x86_64 for CI (GitHub Actions)

def remote_php_toolchain(
        name: str = "php",
        visibility: list[str] = ["PUBLIC"],
        **kwargs) -> None:
    """Set up a hermetic PHP toolchain using static-php-cli binaries.

    Downloads PHP for the current OS/CPU (Linux x86_64, Linux arm64,
    macOS x86_64, macOS arm64). Use in toolchains/BUCK for hermetic builds.
    """
    native.http_archive(
        name = "php_archive",
        urls = [select({
            "DEFAULT": "https://github.com/crazywhalecc/static-php-cli/releases/download/2.8.2/spc-linux-x86_64.tar.gz",
            "prelude//os:linux": select({
                "prelude//cpu:arm64": "https://github.com/crazywhalecc/static-php-cli/releases/download/2.8.2/spc-linux-aarch64.tar.gz",
                "prelude//cpu:x86_64": "https://github.com/crazywhalecc/static-php-cli/releases/download/2.8.2/spc-linux-x86_64.tar.gz",
            }),
            "prelude//os:macos": select({
                "prelude//cpu:arm64": "https://github.com/crazywhalecc/static-php-cli/releases/download/2.8.2/spc-macos-aarch64.tar.gz",
                "prelude//cpu:x86_64": "https://github.com/crazywhalecc/static-php-cli/releases/download/2.8.2/spc-macos-x86_64.tar.gz",
            }),
        })],
        sha256 = select({
            "DEFAULT": "42b410182875ed2076e147db63c6c17f7feb4ba77652b4bb24ae06adb40747dd",
            "prelude//os:linux": select({
                "prelude//cpu:arm64": "28206b05c4028826615c6cd348831d7c5025ffd0e57a9309a4aa04c51fe35d58",
                "prelude//cpu:x86_64": "42b410182875ed2076e147db63c6c17f7feb4ba77652b4bb24ae06adb40747dd",
            }),
            "prelude//os:macos": select({
                "prelude//cpu:arm64": "c934c323df75b6b5d258a90a85e204479341217b23819fcf5546845d8579e39e",
                "prelude//cpu:x86_64": "c98e6059e6e64bfe8710cd76186598bf51dc3ccfe4cafcc504c471d4fc8e3f07",
            }),
        }),
        strip_prefix = "",
        sub_targets = {
            "php": ["spc"],
        },
    )

    native.command_alias(
        name = "php_hermetic",
        exe = ":php_archive[php]",
        visibility = visibility,
    )

    system_php_toolchain(
        name = name,
        interpreter = ":php_hermetic",
        visibility = visibility,
        **kwargs
    )
