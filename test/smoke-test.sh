#!/usr/bin/env bash
# Smoke test for an HMCTS python base image. Usage: test/smoke-test.sh <image-ref>
# Verifies the spec's behavioural requirements: non-root hmcts (uid 1000),
# telemetry importable, telemetry inert without a connection string, telemetry
# active with one (app still starts).
set -euo pipefail

IMAGE="${1:?usage: smoke-test.sh <image-ref>}"
ACTIVATION="hmcts: Application Insights configured"

echo "== 1. Runs as non-root hmcts (uid 1000) =="
uid="$(docker run --rm "$IMAGE" -c 'import os; print(os.getuid())')"
[ "$uid" = "1000" ] || { echo "FAIL: expected uid 1000, got '$uid'"; exit 1; }
echo "PASS: uid=$uid"

echo "== 2. azure-monitor-opentelemetry is importable =="
docker run --rm "$IMAGE" -c 'import azure.monitor.opentelemetry; print("import ok")'

echo "== 3. No telemetry activation without a connection string =="
out="$(docker run --rm "$IMAGE" -c 'print("APP-RAN")' 2>&1)"
echo "$out" | grep -q '^APP-RAN$' || { echo "FAIL: app did not run cleanly:"; echo "$out"; exit 1; }
if echo "$out" | grep -qi "$ACTIVATION"; then echo "FAIL: telemetry activated with no connection string"; exit 1; fi
echo "PASS: inert, app ran"

echo "== 4. Telemetry activates with a connection string (app still starts) =="
cs='InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=https://example.com/'
out="$(docker run --rm -e APPLICATIONINSIGHTS_CONNECTION_STRING="$cs" "$IMAGE" -c 'print("APP-RAN")' 2>&1)"
echo "$out" | grep -q '^APP-RAN$' || { echo "FAIL: app did not run with telemetry:"; echo "$out"; exit 1; }
echo "$out" | grep -qi "$ACTIVATION" || { echo "FAIL: telemetry did not activate:"; echo "$out"; exit 1; }
echo "$out" | grep -qi "log namespace: uvicorn" || { echo "FAIL: default logger namespace not 'uvicorn':"; echo "$out"; exit 1; }
echo "PASS: activated (default namespace 'uvicorn'), app ran"

echo "== 5. File-based connection string + logger namespace =="
csdir="$(mktemp -d)"
printf '%s' "$cs" > "$csdir/APPLICATIONINSIGHTS_CONNECTION_STRING"
chmod 755 "$csdir"; chmod 644 "$csdir/APPLICATIONINSIGHTS_CONNECTION_STRING"  # readable by the image's hmcts uid
out="$(docker run --rm -v "$csdir":/mnt/secrets/ai:ro \
  -e APPLICATIONINSIGHTS_CONNECTION_STRING_FILE=/mnt/secrets/ai/APPLICATIONINSIGHTS_CONNECTION_STRING \
  -e APPLICATIONINSIGHTS_LOGGER_NAMESPACE=cnp \
  "$IMAGE" -c 'import os; print("CS=" + os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING", "")); print("APP-RAN")' 2>&1)"
rm -rf "$csdir"
echo "$out" | grep -q '^APP-RAN$' || { echo "FAIL: app did not run with file-based telemetry:"; echo "$out"; exit 1; }
echo "$out" | grep -qi "$ACTIVATION" || { echo "FAIL: telemetry did not activate from file:"; echo "$out"; exit 1; }
echo "$out" | grep -qF "CS=$cs" || { echo "FAIL: env var not populated from file:"; echo "$out"; exit 1; }
echo "$out" | grep -qi "log namespace: cnp" || { echo "FAIL: logger namespace not applied:"; echo "$out"; exit 1; }
echo "PASS: activated from file, env populated, namespace applied, app ran"

echo "ALL SMOKE TESTS PASSED: $IMAGE"
