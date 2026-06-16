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

# Regenerate the hash-pinned dependency lock (7-day cooldown), synced to both variants:
make lock
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

To change the pinned version, bump `requirements.in` (or let Renovate do it) and run `make lock`.

## External sources (egress allowlist)

The build reaches only these external hosts — nothing else is required:

| Host | Why |
| --- | --- |
| `pypi.org`, `files.pythonhosted.org` | Python packages (telemetry dependencies) |
| `ghcr.io` (`astral-sh/uv`) | the `uv` installer binary |
| `docker.io` (`python:3.13-slim-trixie`) | builder base image |
| `hmctsprod.azurecr.io` / `hmctssbox.azurecr.io` | the imported distroless Python base image |
| `github.com` | GitHub Actions runner / checkout |
