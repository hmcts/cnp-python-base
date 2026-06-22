"""HMCTS base-image telemetry bootstrap.

CPython auto-imports ``sitecustomize`` at interpreter startup when this file's
directory is on PYTHONPATH (see the base image's ``ENV PYTHONPATH=/opt/otel``).

It enables Azure Monitor / Application Insights with **zero application code**. The
connection string is read from ``APPLICATIONINSIGHTS_CONNECTION_STRING``; if that is
unset, it is read from the file named by ``APPLICATIONINSIGHTS_CONNECTION_STRING_FILE``
(e.g. a key vault secret mounted by the HMCTS Helm chart). If neither is set, it logs a
notice and continues, so local development is unaffected. Telemetry setup must never
break the application, so all errors are caught and logged rather than raised.

Logging telemetry is collected from the ``APPLICATIONINSIGHTS_LOGGER_NAMESPACE`` logger
namespace and its children; it defaults to ``uvicorn``. Set it to your app's logger root
to collect that application's own logs instead. Kubernetes probe endpoints (health,
readiness, liveness) are excluded from request tracing by default; override
``OTEL_PYTHON_EXCLUDED_URLS`` to replace or extend that list.
"""
import os
import sys

_conn = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING")
_conn_file = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING_FILE")

if not _conn and _conn_file:
    try:
        with open(_conn_file, encoding="utf-8") as fh:
            _conn = fh.read().strip()
    except OSError as exc:
        print(f"hmcts: could not read connection-string file ({exc})", file=sys.stderr)
    if _conn:
        os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"] = _conn

if _conn:
    try:
        from azure.monitor.opentelemetry import configure_azure_monitor

        os.environ.setdefault("OTEL_PYTHON_EXCLUDED_URLS", "health,readiness,liveness")
        _logger_namespace = os.environ.get("APPLICATIONINSIGHTS_LOGGER_NAMESPACE", "uvicorn")
        configure_azure_monitor(logger_name=_logger_namespace)
        print(
            "hmcts: Application Insights configured via base image "
            f"(log namespace: {_logger_namespace})",
            file=sys.stderr,
        )
    except Exception as exc:  # noqa: BLE001 - telemetry must never break the app
        print(f"hmcts: Application Insights setup skipped ({exc})", file=sys.stderr)
else:
    print("hmcts: Application Insights not enabled", file=sys.stderr)
