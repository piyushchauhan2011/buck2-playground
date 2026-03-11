# Deployment

Deployment is **manual** from the main branch.

## Release Artifacts

Release artifacts are built by the [Release workflow](../.github/workflows/release.yml):

- **RC artifacts**: Push to `release/<app>/<version>` (e.g. `release/api-php/1.0.0`) → build `{app}-{version}-rc.N.tar.gz`
- **Final artifacts**: Push tag `{app}/v{version}` (e.g. `api-php/v1.0.0`) → build `{app}-{version}.tar.gz`

Artifacts are uploaded to GitHub Actions. Download from the workflow run.

## Deployable Apps


| App           | App name      | Path                  |
| ------------- | ------------- | --------------------- |
| API PHP       | api-php       | domains/api/php       |
| API PHP Admin | api-php-admin | domains/api/php-admin |


## Deploy Process

1. Download the tarball from the Actions release artifact.
2. Extract to the target server.
3. Configure `.env` (copy from `.env.example`, set `APP_KEY`, etc.).
4. Run `php artisan config:cache` etc. as needed for your environment.

