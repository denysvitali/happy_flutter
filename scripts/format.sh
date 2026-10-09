#!/usr/bin/env bash
# Format (or verify) the repository's hand-written Dart.
#
#   scripts/format.sh            rewrite every tracked, non-generated .dart file
#   scripts/format.sh --check    exit 1 and list files that need formatting
#   scripts/format.sh --staged   restrict to files staged in the index
#
# Generated Dart is excluded on purpose: the CI codegen job regenerates it and
# fails on any diff, so reformatting it here would break that job. Keep the
# exclusion list in sync with "Reject generated-code drift" in ci.yml.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

check=0
staged=0
for arg in "$@"; do
  case "$arg" in
    --check) check=1 ;;
    --staged) staged=1 ;;
    *)
      echo "usage: $0 [--check] [--staged]" >&2
      exit 2
      ;;
  esac
done

if command -v mise >/dev/null 2>&1; then
  dart_cmd=(mise exec -- dart)
else
  dart_cmd=(dart)
fi

generated='(\.g\.dart|\.freezed\.dart|\.mocks\.dart)$|^lib/l10n_generated/|^lib/core/native/generated/'

if [ "$staged" -eq 1 ]; then
  list=(git diff --cached --name-only --diff-filter=ACMR -z -- '*.dart')
else
  list=(git ls-files -z -- '*.dart')
fi

files=()
while IFS= read -r -d '' file; do
  if [[ ! "$file" =~ $generated ]] && [ -f "$file" ]; then
    files+=("$file")
  fi
done < <("${list[@]}")

if [ "${#files[@]}" -eq 0 ]; then
  exit 0
fi

if [ "$check" -eq 1 ]; then
  if ! "${dart_cmd[@]}" format --output=none --set-exit-if-changed "${files[@]}"; then
    echo >&2
    echo "Dart files above are not formatted. Run: scripts/format.sh" >&2
    exit 1
  fi
else
  "${dart_cmd[@]}" format "${files[@]}"
fi
