# syntax=docker/dockerfile:1
# HMCTS base image for Python services (distroless-debug: includes a busybox shell).

# Base image lives in both hmctsprod and hmctssbox. Default to prod (steady-state/CI);
# override for SBOX-first local builds: --build-arg BASE_REGISTRY=hmctssbox.azurecr.io
ARG BASE_REGISTRY=hmctsprod.azurecr.io

# ---- Builder: install telemetry packages (distroless has no pip) ----
# renovate: datasource=pypi depName=azure-monitor-opentelemetry
ARG AZURE_MONITOR_OTEL_VERSION=1.8.8
FROM python:3.13-slim-trixie AS builder
ARG AZURE_MONITOR_OTEL_VERSION
RUN pip install --no-cache-dir --target=/otel \
    "azure-monitor-opentelemetry==${AZURE_MONITOR_OTEL_VERSION}"

# ---- Final: distroless Python 3.13 (debug) ----
# hadolint ignore=DL3007
FROM ${BASE_REGISTRY}/imported/distroless/python3:debug

COPY --from=builder /otel /opt/otel
COPY sitecustomize.py /opt/otel/sitecustomize.py
ENV PYTHONPATH=/opt/otel

COPY group /etc/group
COPY passwd /etc/passwd

COPY --chown=hmcts:hmcts app/ /opt/app/
WORKDIR /opt/app
USER hmcts

ENTRYPOINT ["/usr/bin/python3.13"]
