#!/usr/bin/env bash
# Canonical local invocation for the chaos harness.
#
# Skipped in CI — run on a workstation with an attached emulator and
# Maestro installed (https://maestro.mobile.dev/).  CI does not have
# access to either, by design.
set -euo pipefail

UPSTREAM="${UPSTREAM:-https://staging.happy.engineering}"
PROFILE="${PROFILE:-noisy}"
SEED="${SEED:-$RANDOM}"
LISTEN_PORT="${LISTEN_PORT:-8080}"

echo "==> starting chaos proxy (profile=$PROFILE seed=$SEED)"
dart run "$(dirname "$0")/chaos_proxy.dart" \
    --listen="$LISTEN_PORT" \
    --upstream="$UPSTREAM" \
    --profile="$PROFILE" \
    --seed="$SEED" &
PROXY_PID=$!
trap 'kill "$PROXY_PID" 2>/dev/null || true' EXIT

# Give the proxy a moment to bind.
sleep 1

echo "==> running Maestro flow against http://10.0.2.2:$LISTEN_PORT"
APP_BASE_URL="http://10.0.2.2:$LISTEN_PORT" \
    maestro test "$(dirname "$0")/maestro_flow.yaml"
