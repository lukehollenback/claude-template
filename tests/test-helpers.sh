#!/usr/bin/env bash
# Minimal bash test harness.

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
  local description="$1" expected="$2" actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$expected" == "$actual" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
  fi
}

assert_contains() {
  local description="$1" needle="$2" haystack="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if echo "$haystack" | grep -qF "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    Expected to contain: $needle"
    echo "    Actual: $haystack"
  fi
}

assert_file_exists() {
  local description="$1" filepath="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -f "$filepath" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    File not found: $filepath"
  fi
}

assert_file_not_exists() {
  local description="$1" filepath="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ ! -f "$filepath" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    File should not exist: $filepath"
  fi
}

assert_exit_code() {
  local description="$1" expected="$2" actual="$3"
  assert_equals "$description" "$expected" "$actual"
}

print_results() {
  echo ""
  echo "Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed."
  if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
  fi
}
