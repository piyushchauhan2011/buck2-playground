# JS/TS Project Quickstart (`domains/api/js`)

This service is now TypeScript + Express 5 + Vitest.

## Local commands

```bash
cd domains/api/js
npm install
npm run lint
npm run format:check
npm run typecheck
npm run test
npm run build
npm run dev
```

Endpoints:

- `http://localhost:3000/`
- `http://localhost:3000/health`

## Buck commands

Build/lint/typecheck:

```bash
# Fastest (single Buck invocation)
buck2 build //domains/api:api_js_lint //domains/api:api_js_fmt //domains/api:api_js_typecheck //domains/api:api_js_build

# Or individually
buck2 build //domains/api:api_js_lint
buck2 build //domains/api:api_js_fmt
buck2 build //domains/api:api_js_typecheck
buck2 build //domains/api:api_js_build
```

Run tests with Buck (real test target):

```bash
buck2 test //domains/api:api_js_vitest
```

To inspect cache/useful execution stats:

```bash
buck2 test //domains/api:api_js_vitest -v 2
buck2 build //domains/api:api_js_build -v 2
```
