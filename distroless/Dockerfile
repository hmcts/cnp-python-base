# syntax=docker/dockerfile:1
# HMCTS base image for Python services (distroless, non-root, App Insights pre-wired).

# Base image lives in both hmctsprod and hmctssbox. Default to prod (steady-state/CI);
# override for SBOX-first local builds: --build-arg BASE_REGISTRY=hmctssbox.azurecr.io
ARG BASE_REGISTRY=hmctsprod.azurecr.io

# ---- Builder: install telemetry deps with uv from the committed uv.lock ----
# Supply-chain hardening: uv sync --frozen installs the exact committed lock (every
# package + hash pinned in uv.lock) with no re-resolution. The 7-day cooldown is applied
# when the lock is generated (from [tool.uv] exclude-newer in pyproject.toml) and UV_MALWARE_CHECK
# blocks known-bad packages before install.
FROM python:3.13-slim-trixie AS builder
COPY --from=ghcr.io/astral-sh/uv:0.11.21 /uv /uvx /bin/
ENV UV_MALWARE_CHECK=1 \
    UV_PYTHON_DOWNLOADS=never \
    UV_LINK_MODE=copy
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --python /usr/local/bin/python3.13

# ---- Final: distroless Python 3.13 ----
# hadolint ignore=DL3007
FROM ${BASE_REGISTRY}/imported/distroless/python3:latest

# Telemetry deps (from the uv venv) + zero-code bootstrap (sitecustomize auto-imported at startup).
COPY --from=builder /app/.venv/lib/python3.13/site-packages /opt/otel
COPY sitecustomize.py /opt/otel/sitecustomize.py
ENV PYTHONPATH=/opt/otel

# Non-root hmcts user (uid/gid 1000). Distroless has no useradd, so copy passwd/group.
COPY group /etc/group
COPY passwd /etc/passwd

COPY --chown=hmcts:hmcts app/ /opt/app/
WORKDIR /opt/app
USER hmcts

ENTRYPOINT ["/usr/bin/python3.13"]
# Consumers supply their app via CMD, e.g. CMD ["myapp.py"] or CMD ["-m", "myapp"].
