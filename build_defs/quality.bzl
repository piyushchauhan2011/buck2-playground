"""Quality targets: lint, fmt, sast - compose through dependency graph."""

def quality_targets(name, srcs, lang):
    """Define lint, fmt, sast targets for a given package.
    Naming: <name>#lint, <name>#fmt, <name>#sast
    """
    # These would be used as a macro - for now we define inline in BUCK
    pass
