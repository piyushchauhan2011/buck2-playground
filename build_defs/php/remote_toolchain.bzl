"""Hermetic PHP toolchain - uses static-php-cli from third_party/php.

The PHP archive lives in root//third_party/php so genrules avoid cross-cell
path issues. Use remote_php_toolchain() in toolchains/BUCK for hermetic builds.
"""

load(":toolchain.bzl", "system_php_toolchain")

def remote_php_toolchain(
        name: str = "php",
        visibility: list[str] = ["PUBLIC"],
        **kwargs) -> None:
    """Set up a hermetic PHP toolchain using static-php-cli from third_party/php.

    The PHP binary is at root//third_party/php:php_hermetic (same cell as
    genrules) to avoid cross-cell $(exe) path resolution issues.
    """
    system_php_toolchain(
        name = name,
        interpreter = "//third_party/php:php_hermetic",
        visibility = visibility,
        **kwargs
    )
