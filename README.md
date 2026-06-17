# cnp-python-base

Base Docker image for HMCTS Python services running in containers (Kubernetes) — distroless, non-root, with Azure Application Insights pre-wired. Follows the same conventions as [`cnp-java-base`](https://github.com/hmcts/cnp-java-base).

## Supported images

| Tag | OS | Python |
| --- | --- | --- |
| `hmctsprod.azurecr.io/base/python:3.13-distroless` | Debian 13 (trixie) | 3.13 |
| `hmctsprod.azurecr.io/base/python:3.13-distroless-debug` | Debian 13 (trixie) | 3.13 |

Use `distroless` for production; `distroless-debug` adds a shell for troubleshooting in non-prod.

## Features

- **Non-root by default** — runs as `hmcts` (uid 1000). Bind to ports **≥ 1024** (e.g. `8080`); `/opt/app` is writable by the app.
- **Application Insights, zero app code** — set `APPLICATIONINSIGHTS_CONNECTION_STRING` and telemetry is configured at startup. Leave it unset and it's a no-op, so local dev is unaffected.

## Usage

The image's entrypoint is the Python interpreter, so your `CMD` is whatever you'd pass to `python` — a script, a module, or a server.

**Simple app (no dependencies):**

```dockerfile
FROM hmctsprod.azurecr.io/base/python:3.13-distroless
COPY . /opt/app/
CMD ["myapp.py"]      # or ["-m", "myapp"] / ["-m", "gunicorn", "myapp:app", "-b", "0.0.0.0:8080"]
```

**App with dependencies** — declare them in your own `pyproject.toml`, install them with uv in a build stage, and copy them onto `PYTHONPATH` (the distroless image has no installer):

```dockerfile
# Build stage: resolve + install your app's dependencies with uv
FROM python:3.13-slim-trixie AS deps
COPY --from=ghcr.io/astral-sh/uv:0.11.21 /uv /bin/
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# Your app on the HMCTS base
FROM hmctsprod.azurecr.io/base/python:3.13-distroless
COPY --from=deps /app/.venv/lib/python3.13/site-packages /opt/app/deps
COPY . /opt/app/
ENV PYTHONPATH=/opt/app/deps:/opt/otel    # keep /opt/otel so App Insights still loads
CMD ["myapp.py"]
```

Generate `uv.lock` once with `uv lock` (in the dir with your `pyproject.toml`) and commit it.

Set `APPLICATIONINSIGHTS_CONNECTION_STRING` in the app's environment to enable telemetry.

---

## Maintaining this repo

*(The rest is for working on this repo — not needed to consume the image.)*

Two variants live under `distroless/` and `distroless-debug/` (identical bar the base tag). Dependencies are managed with [uv](https://docs.astral.sh/uv/): `pyproject.toml` declares them and `uv.lock` pins every package (incl. transitive) with SHA256 hashes. The build installs the exact lock with `uv sync --frozen` (no re-resolution). Supply-chain hardening: a 7-day cooldown on the lock (`uv lock --exclude-newer` + Renovate `minimumReleaseAge`) and `UV_MALWARE_CHECK=1`.

```bash
az acr login --name hmctssbox

# build + smoke test
docker buildx build --load --build-arg BASE_REGISTRY=hmctssbox.azurecr.io -t base/python:3.13-distroless distroless/
./test/smoke-test.sh base/python:3.13-distroless

# update dependencies: edit distroless/pyproject.toml, then regenerate the hash-pinned
# lock with a 7-day cooldown and copy it to the debug variant (both share one lock)
docker run --rm -v "$PWD/distroless":/work -w /work ghcr.io/astral-sh/uv:0.11.21-python3.13-trixie-slim \
  sh -c 'uv lock --exclude-newer "$(date -u -d "7 days ago" "+%Y-%m-%dT%H:%M:%SZ")"'
cp distroless/pyproject.toml distroless/uv.lock distroless-debug/
```

CI/CD (GitHub Actions) builds multi-arch and publishes to SBOX (PROD to follow). Build egress: PyPI, `ghcr.io` (uv), Docker Hub, the ACR, GitHub.
