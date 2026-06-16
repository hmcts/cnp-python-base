# cnp-python-base

Base Docker image for HMCTS Python services running in containers (Kubernetes),
following the same conventions as `cnp-java-base`. Distroless, non-root, with
Azure Monitor / Application Insights pre-wired.

## Supported images

| Tag | OS | Python |
| --- | --- | --- |
| `hmctsprod.azurecr.io/base/python:3.13-distroless` | Debian 13 (trixie) | 3.13 |
| `hmctsprod.azurecr.io/base/python:3.13-distroless-debug` | Debian 13 (trixie) | 3.13 |

Also published to `hmctssbox.azurecr.io/base/python:3.13-*`.

## Features

- **Non-root by default** — runs as the `hmcts` user (uid/gid 1000), home `/opt/app`.
- **Application Insights with zero app code** — set `APPLICATIONINSIGHTS_CONNECTION_STRING`
  and telemetry is configured automatically at interpreter startup. If the variable is
  unset, telemetry is completely inert (local development is unaffected).
- **`-debug` variant** — same image plus a busybox shell for troubleshooting.

The bundled telemetry version (Renovate-managed):

```
# renovate: datasource=pypi depName=azure-monitor-opentelemetry
ARG AZURE_MONITOR_OTEL_VERSION=1.8.8
```

## Usage

```dockerfile
FROM hmctsprod.azurecr.io/base/python:3.13-distroless
COPY --chown=hmcts:hmcts . /opt/app/
CMD ["myapp.py"]            # or ["-m", "myapp"] / ["-m", "gunicorn", "myapp:app"]
```

Provide `APPLICATIONINSIGHTS_CONNECTION_STRING` in the app's environment to enable telemetry.

## Local development

```bash
az acr login --name hmctsprod   # to pull the base image (or hmctssbox for sbox-first)
make test                       # build both variants and run smoke tests
# For SBOX-first local builds, pull the base from the sandbox registry:
make test BASE_REGISTRY=hmctssbox.azurecr.io
```
