#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI_ROOT="${HAPPY_CLI_GO_PATH:-"$ROOT/../happy-cli-go"}"

if [[ ! -d "$CLI_ROOT" ]]; then
  echo "happy-cli-go checkout not found: $CLI_ROOT" >&2
  echo "Set HAPPY_CLI_GO_PATH=/path/to/happy-cli-go" >&2
  exit 1
fi

run() {
  echo
  echo "==> $*"
  "$@"
}

run_in_flutter() {
  (
    cd "$ROOT"
    HAPPY_CLI_GO_PATH="$CLI_ROOT" run mise exec -- "$@"
  )
}

run_in_cli() {
  (
    cd "$CLI_ROOT"
    run mise exec -- "$@"
  )
}

run_in_flutter flutter test \
  test/integration/cross_repo_contract_test.dart \
  test/services/sync_service_send_protocol_test.dart \
  test/integration/concurrent_send_message_e2e_test.dart \
  test/integration/message_outbox_e2e_test.dart \
  test/integration/session_spawning_e2e_test.dart

run_in_cli go test \
  ./internal/wsapi \
  ./internal/api \
  ./internal/cli \
  ./internal/server/auth \
  -run 'Test(TokenGenerator|.*E2E.*|.*Message.*|.*SessionSync.*|.*Ready.*|.*Dedup.*)'
