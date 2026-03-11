"""PHP/Laravel project macro - backward-compat re-export.

New code should use: load("//build_defs/php:php_project.bzl", "php_project")
"""

load("//build_defs/php:php_project.bzl", _php_project = "php_project")

def php_project(**kwargs):
    return _php_project(**kwargs)
