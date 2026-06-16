# syntax=docker/dockerfile:1
# HMCTS base image for Python services (distroless-debug: includes a busybox shell).

# Base image lives in both hmctsprod and hmctssbox. Default to prod (steady-state/CI);
# override for SBOX-first local builds: --build-arg BASE_REGISTRY=hmctssbox.azurecr.io
ARG BASE_REGISTRY=hmctsprod.azurecr.io

FROM python:3.13-slim-trixie AS builder
# uv pinned by version (Renovate-managed)
COPY --from=ghcr.io/astral-sh/uv:0.11.21 /uv /uvx /bin/
ENV UV_MALWARE_CHECK=1
WORKDIR /build
COPY requirements.txt .
RUN uv pip install \
      --no-cache \
      --target=/otel \
      --python /usr/local/bin/python3.13 \
      --require-hashes \
      --index-url https://pypi.org/simple \
      -r requirements.txt

# ---- Final: distroless Python 3.13 (debug) ----
# hadolint ignore=DL3007
FROM ${BASE_REGISTRY}/imported/distroless/python3:debug

# Telemetry packages + zero-code bootstrap (sitecustomize auto-imported at startup).
COPY --from=builder /otel /opt/otel
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
