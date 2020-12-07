#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 5.4.3 Ensure default group for the root account is GID 0 (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Set default group for root account to 0."

USER='root'
EXPECTED_GID='0'

# This function will be called if the script status is on enabled / audit mode
audit() {
    if [ "$(grep "^root:" /etc/passwd | cut -f4 -d:)" = 0 ]; then
        ok "Root group has GID $EXPECTED_GID"
    else
        crit "Root group GID should be $EXPECTED_GID"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$(grep "^root:" /etc/passwd | cut -f4 -d:)" = 0 ]; then
        ok "Root group GID is $EXPECTED_GID"
    else
        warn "Root group GID is not $EXPECTED_GID -- Fixing"
        usermod -g "$EXPECTED_GID" "$USER"
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "$CIS_ROOT_DIR"/lib/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "$CIS_ROOT_DIR"/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
