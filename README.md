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

**App with dependencies** — install them in a build stage and copy them in (the distroless image has no `pip`):

```dockerfile
FROM python:3.13-slim-trixie AS build
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/build/deps -r requirements.txt

FROM hmctsprod.azurecr.io/base/python:3.13-distroless
COPY --from=build /build/deps /opt/app/deps
COPY . /opt/app/
ENV PYTHONPATH=/opt/app/deps:/opt/otel    # keep /opt/otel so App Insights still loads
CMD ["myapp.py"]
```

Set `APPLICATIONINSIGHTS_CONNECTION_STRING` in the app's environment to enable telemetry.

---

## Maintaining this repo

*(The rest is for working on this repo — not needed to consume the image.)*

Two variants live under `distroless/` and `distroless-debug/` (identical bar the base tag). Dependencies are supply-chain hardened: `requirements.txt` pins every package (incl. transitive) with SHA256 hashes, installed via `uv pip install --require-hashes` from PyPI only, with a 7-day cooldown (uv `--exclude-newer` + Renovate `minimumReleaseAge`) and `UV_MALWARE_CHECK=1`.

```bash
az acr login --name hmctssbox

# build + smoke test
docker buildx build --load --build-arg BASE_REGISTRY=hmctssbox.azurecr.io -t base/python:3.13-distroless distroless/
./test/smoke-test.sh base/python:3.13-distroless

# regenerate the hash-pinned lock (7-day cooldown) and sync both variants
CUTOFF=$(python3 -c "import datetime; print((datetime.date.today() - datetime.timedelta(days=7)).isoformat())")
docker run --rm -v "$PWD/distroless":/work -w /work python:3.13-slim-trixie \
  sh -c "pip install -q uv && uv pip compile --generate-hashes --exclude-newer $CUTOFF requirements.in -o requirements.txt"
cp distroless/requirements.in distroless/requirements.txt distroless-debug/
```

CI/CD (GitHub Actions) builds multi-arch and publishes to SBOX (PROD to follow). Build egress: PyPI, `ghcr.io` (uv), Docker Hub, the ACR, GitHub.
