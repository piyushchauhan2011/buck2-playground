# JS/TS Project Quickstart (`domains/api/js`)

This service is now TypeScript + Express 5 + Vitest.

## Local commands

```bash
# From the repo root — install all workspace packages
pnpm install

# Run scripts for this package (from repo root)
pnpm --filter api-js-service run lint
pnpm --filter api-js-service run format:check
pnpm --filter api-js-service run typecheck
pnpm --filter api-js-service run test
pnpm --filter api-js-service run build
pnpm --filter api-js-service run dev
```

Endpoints:

- `http://localhost:3000/`
- `http://localhost:3000/health`

## Buck commands

Build/lint/typecheck:

```bash
# Fastest (single Buck invocation)
buck2 build //domains/api/js:api_js_lint //domains/api/js:api_js_fmt //domains/api/js:api_js_typecheck //domains/api/js:api_js_build

# Or individually
buck2 build //domains/api/js:api_js_lint
buck2 build //domains/api/js:api_js_fmt
buck2 build //domains/api/js:api_js_typecheck
buck2 build //domains/api/js:api_js_build
```

Run tests with Buck (real test target):

```bash
buck2 test //domains/api/js:api_js_vitest
```

To inspect cache/useful execution stats:

```bash
buck2 test //domains/api/js:api_js_vitest -v 2
buck2 build //domains/api/js:api_js_build -v 2
```
