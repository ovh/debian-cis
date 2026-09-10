#!/bin/bash
# run-shellcheck
set -eu
# shellcheck disable=2034
SUDO_CMD=''
source lib/utils.sh
case_result=failed
upgrade_applied=0
apt-get() {
    if [[ " $* " == *" upgrade -y "* ]]; then
        upgrade_applied=1
        return 0
    fi
    case "$case_result" in
    failed) return 100 ;;
    empty) printf '0 upgraded, 0 newly installed\n' ;;
    pending) printf 'Inst package-one [1] (2 Debian:stable)\nInst package-two [1] (2 Debian:stable)\n' ;;
    esac
}
apt_check_updates "CIS_ENGINE_TEST_$$"
[ "$FNRET" = 128 ] || {
    echo 'FAIL: failed APT simulation was reported as a successful audit'
    exit 1
}
case_result=empty
apt_check_updates "CIS_ENGINE_TEST_$$"
[ "$FNRET" = 0 ]
case_result=pending
apt_check_updates "CIS_ENGINE_TEST_$$"
[ "$FNRET" = 1 ]
[[ "$RESULT" == *'2 updates available'* ]]
echo 'PASS: failed, empty and non-empty APT simulations are distinguished'

# A failed probe must never cause the apply phase to start an upgrade.
# shellcheck source=/dev/null
source <(sed '/^# Source Root Dir Parameter/,$d' bin/hardening/install_updates.sh)
info() { :; }
ok() { :; }
crit() { :; }
apt_update_if_needed() { return 0; }

case_result=failed
upgrade_applied=0
audit
[ "$INSTALL_UPDATES_PENDING" = 1 ]
apply
[ "$upgrade_applied" = 0 ] || {
    echo 'FAIL: failed APT simulation triggered an upgrade'
    exit 1
}

case_result=pending
upgrade_applied=0
audit
[ "$INSTALL_UPDATES_PENDING" = 0 ]
apply
[ "$upgrade_applied" = 1 ] || {
    echo 'FAIL: confirmed pending updates did not trigger an upgrade'
    exit 1
}

apt_update_if_needed() { return 1; }
upgrade_applied=0
audit
[ "$INSTALL_UPDATES_PENDING" = 1 ]
apply
[ "$upgrade_applied" = 0 ] || {
    echo 'FAIL: failed metadata refresh triggered an upgrade'
    exit 1
}

echo 'PASS: only confirmed updates enable the upgrade phase'
