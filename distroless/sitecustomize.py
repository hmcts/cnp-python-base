"""HMCTS base-image telemetry bootstrap.

CPython auto-imports ``sitecustomize`` at interpreter startup when this file's
directory is on PYTHONPATH (see the base image's ``ENV PYTHONPATH=/opt/otel``).

It enables Azure Monitor / Application Insights with **zero application code** when
``APPLICATIONINSIGHTS_CONNECTION_STRING`` is set as an environment variable, or
when the secret is mounted as a file under ``/mnt/secrets/`` by the CSI Secret
Store driver (the HMCTS Key Vault volume mount convention).

The secrets scan mirrors the Node.js ``@hmcts/properties-volume`` pattern: every
file found under ``/mnt/secrets/*/*`` is read and its contents injected into
``os.environ`` using the filename as the variable name, unless that variable is
already set. This runs before the Application Insights check so that secrets
mounted from Key Vault are available without requiring a Kubernetes Secret sync.

When the variable is absent or empty it is a complete no-op, so local development
and connection-string-less runs are unaffected. Telemetry setup must never break
the application, so all errors are caught and logged rather than raised.
"""
import os
import sys
from pathlib import Path

_SECRETS_ROOT = Path("/mnt/secrets")


def _load_secrets_volume() -> None:
    """Inject Key Vault secrets mounted as files into os.environ.

    Scans /mnt/secrets/<keyvault>/<alias> and sets each file's content as an
    environment variable named after the file (alias), skipping any variable
    that is already set in the environment.
    """
    if not _SECRETS_ROOT.is_dir():
        return
    for secret_file in _SECRETS_ROOT.glob("*/*"):
        if not secret_file.is_file():
            continue
        var_name = secret_file.name
        if var_name not in os.environ:
            try:
                os.environ[var_name] = secret_file.read_text().strip()
            except Exception as exc:  # noqa: BLE001
                print(f"hmcts: could not load secret {secret_file} ({exc})", file=sys.stderr)


_load_secrets_volume()

_conn = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING")
if _conn:
    try:
        from azure.monitor.opentelemetry import configure_azure_monitor

        configure_azure_monitor()
        print("hmcts: Application Insights configured via base image", file=sys.stderr)
    except Exception as exc:  # noqa: BLE001 - telemetry must never break the app
        print(f"hmcts: Application Insights setup skipped ({exc})", file=sys.stderr)
