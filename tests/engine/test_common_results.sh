#!/bin/bash
# run-shellcheck
set -eu
LOGLEVEL=silent
# shellcheck disable=2034
SCRIPT_NAME="test"
# shellcheck disable=2034
CRITICAL_ERRORS_NUMBER=0
source lib/common.sh
[ "$(div 100 376)" = '0.26' ] || {
    echo 'FAIL: percentage below one is not JSON-compatible'
    exit 1
}
[ "$(div 100 3)" = '33.33' ]
[ "$(div 0 1)" = 0 ]
[ "$(div 1 0)" = 'N.A' ]
sudo() { return 1; }
result=0
output=$(sudo_wrapper cat /test/denied) || result=$?
[ "$result" -ne 0 ] || {
    echo 'FAIL: denied sudo command returned success'
    exit 1
}
[ -z "$output" ] || {
    echo 'FAIL: diagnostics leaked to stdout'
    exit 1
}
echo 'PASS: fractional percentages and denied privileged reads'
