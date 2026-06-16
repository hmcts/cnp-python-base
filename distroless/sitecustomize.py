"""HMCTS base-image telemetry bootstrap.

CPython auto-imports ``sitecustomize`` at interpreter startup when this file's
directory is on PYTHONPATH (see the base image's ``ENV PYTHONPATH=/opt/otel``).

It enables Azure Monitor / Application Insights with **zero application code** when
``APPLICATIONINSIGHTS_CONNECTION_STRING`` is set. When the variable is absent or
empty it is a complete no-op, so local development and connection-string-less runs
are unaffected. Telemetry setup must never break the application, so all errors are
caught and logged rather than raised.
"""
import os
import sys

_conn = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING")
if _conn:
    try:
        from azure.monitor.opentelemetry import configure_azure_monitor

        configure_azure_monitor()
        print("hmcts: Application Insights configured via base image", file=sys.stderr)
    except Exception as exc:  # noqa: BLE001 - telemetry must never break the app
        print(f"hmcts: Application Insights setup skipped ({exc})", file=sys.stderr)
