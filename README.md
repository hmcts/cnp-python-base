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

Telemetry packages are pinned with SHA256 hashes in `distroless/requirements.txt` (generated
from `requirements.in`) and updated by Renovate with a 7-day cooldown — see **Supply chain** below.

## Usage

Simple app (no third-party dependencies):

```dockerfile
FROM hmctsprod.azurecr.io/base/python:3.13-distroless
COPY . /opt/app/
CMD ["myapp.py"]            # or ["-m", "myapp"] / ["-m", "gunicorn", "myapp:app"]
```

App with dependencies — install them in a build stage and copy them in (the distroless
image has no `pip` at runtime):

```dockerfile
# ---- Build stage: install your dependencies ----
FROM python:3.13-slim-trixie AS build
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/build/deps -r requirements.txt

# ---- Final stage: the HMCTS distroless Python base ----
FROM hmctsprod.azurecr.io/base/python:3.13-distroless
COPY --from=build /build/deps /opt/app/deps
COPY . /opt/app/
# Keep /opt/otel on PYTHONPATH so the App Insights bootstrap still loads.
ENV PYTHONPATH=/opt/app/deps:/opt/otel
CMD ["myapp.py"]
```

Provide `APPLICATIONINSIGHTS_CONNECTION_STRING` in the app's environment to enable telemetry.

> **Note:** the base image sets `PYTHONPATH=/opt/otel` (where the telemetry bootstrap lives).
> If you set `PYTHONPATH` yourself, **include `/opt/otel`** or the zero-code App Insights setup
> won't load.

## Local development

```bash
az acr login --name hmctssbox    # to pull the base image (use hmctsprod for the prod base)

# Build + smoke-test a variant (override BASE_REGISTRY to choose the base registry):
docker buildx build --load --build-arg BASE_REGISTRY=hmctssbox.azurecr.io \
  -t base/python:3.13-distroless distroless/
./test/smoke-test.sh base/python:3.13-distroless

# Regenerate the hash-pinned lock (7-day cooldown) and sync both variants:
CUTOFF=$(python3 -c "import datetime; print((datetime.date.today() - datetime.timedelta(days=7)).isoformat())")
docker run --rm -v "$PWD/distroless":/work -w /work python:3.13-slim-trixie \
  sh -c "pip install -q uv && uv pip compile --generate-hashes --exclude-newer $CUTOFF requirements.in -o requirements.txt"
cp distroless/requirements.in distroless/requirements.txt distroless-debug/
```

## Supply chain

Python dependencies are hardened against supply-chain attacks:

- **Hash-pinned lock** — `requirements.in` declares the top-level dependency; `requirements.txt`
  pins **every** transitive dependency with SHA256 hashes. The build installs with
  `uv pip install --require-hashes`, so any package whose bytes don't match is rejected.
- **Single trusted index** — installs come only from PyPI (`--index-url https://pypi.org/simple`,
  no `--extra-index-url`), preventing dependency-confusion attacks.
- **Dependency cooldown** — the lock is generated with `uv … --exclude-newer` (7 days) and
  Renovate uses `minimumReleaseAge: "7 days"`, so a freshly-published (possibly compromised)
  release is never adopted immediately.
- **Malware check** — `UV_MALWARE_CHECK=1` blocks known-malicious packages before any code runs.

To change the pinned version, bump `requirements.in` (or let Renovate do it) and regenerate the lock (see **Local development** above).

## External sources (egress allowlist)

The build reaches only these external hosts — nothing else is required:

| Host | Why |
| --- | --- |
| `pypi.org`, `files.pythonhosted.org` | Python packages (telemetry dependencies) |
| `ghcr.io` (`astral-sh/uv`) | the `uv` installer binary |
| `docker.io` (`python:3.13-slim-trixie`) | builder base image |
| `hmctsprod.azurecr.io` / `hmctssbox.azurecr.io` | the imported distroless Python base image |
| `github.com` | GitHub Actions runner / checkout |
