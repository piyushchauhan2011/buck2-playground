# Sparse Checkout Playbook

## One-time clone (partial + sparse)

```bash
git clone --filter=blob:none --sparse https://github.com/org/monorepo.git
cd monorepo
git sparse-checkout set domains/api domains/backend libs/common
```

## Team profiles

| Profile   | Paths                                             |
|-----------|---------------------------------------------------|
| backend   | domains/api, domains/backend, libs/common         |
| frontend  | domains/api/js, domains/api, libs/common          |
| ml        | domains/ml, libs/common                           |
| infra     | domains/infra, libs/common                        |
| jvm       | domains/jvm, libs/common                          |

Apply a profile:

```bash
./scripts/sparse-checkout.sh backend
```

## Cone mode (recommended)

```bash
git sparse-checkout init --cone
git sparse-checkout set domains/api domains/backend
```

Cone mode restricts to directories only and is faster.

## New clone with profile

```bash
git clone --filter=blob:none --sparse <repo-url>
cd <repo>
git sparse-checkout set $(cat scripts/sparse-checkout-profiles/backend | tr '\n' ' ')
```
