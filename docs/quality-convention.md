# Quality Target Convention

All quality checks are modeled as Buck targets with consistent naming:

| Suffix | Purpose | Example Tools |
|--------|---------|---------------|
| `_lint` | Static analysis, style checks | ruff, eslint, clippy, shellcheck |
| `_fmt` | Format verification/fix | black, prettier, rustfmt |
| `_sast` | Static application security | bandit, semgrep, cargo-audit |

## Query Patterns

```bash
# All lint targets in api domain
buck2 cquery "attrfilter(name, 'lint', //domains/api/...)" --output label

# All quality targets (lint + fmt + sast)
buck2 cquery "attrfilter(name, '(lint|fmt|sast)', //domains/...)" --output label
```

## Compose by Domain

Quality targets compose through the dependency graph. To run quality for a domain and its deps:

```bash
buck2 build $(buck2 cquery "filter('lint', deps(//domains/api:api_rust))" --output label)
```
