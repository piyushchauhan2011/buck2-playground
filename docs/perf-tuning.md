# Performance Tuning

## Remote Cache

Add to `.buckconfig` (or a mode file):

```ini
[buck2_re_client]
  engine_address = grpc://your-re-server:443
  action_cache_address = grpc://your-cache:443
  cas_address = grpc://your-cas:443
  instance_name = your-instance
```

Environment variables for secrets: `%env:RE_TLS_CA`, `%env:RE_CLIENT_CERT`.

## Hermeticity

- **Stable toolchains** - pin rustc/go/javac versions so cache keys stay stable
- **No timestamps in outputs** - avoid `date`, `__DATE__`, or build-id in artifacts
- **Declare all inputs** - every file read must be in `srcs` or `deps`
- **Deterministic ordering** - use `sorted()` or explicit order in genrule `cmd`

## Identify Hotspots

```bash
# Actions for a target
buck2 aquery "deps(//domains/api:api_rust)" --output-attribute cmd

# Find expensive deps
buck2 cquery "deps(//domains/...)" --output graphviz | dot -Tpng -o deps.png
```

## Reduce Pipeline Times

1. Enable remote cache first (read-only is low-risk)
2. Enable remote execution for parallel jobs
3. Use affected CI to skip unchanged targets
4. Shard tests across CI runners by domain
