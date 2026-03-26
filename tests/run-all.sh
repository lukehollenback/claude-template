#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running all claude-template tests..."
echo ""

failed=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  [[ -f "$test_file" ]] || continue
  echo "--- $(basename "$test_file") ---"
  if bash "$test_file"; then
    echo ""
  else
    failed=$((failed + 1))
    echo ""
  fi
done

if [[ $failed -gt 0 ]]; then
  echo "FAILED: $failed test file(s) had failures."
  exit 1
else
  echo "All test files passed."
fi
