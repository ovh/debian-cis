#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.2.1 Ensure Password Fields are Not Empty (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure password fields are not empty in /etc/shadow."

# This function will be called if the script status is on enabled / audit mode
audit() {
    info "Checking if accounts have an empty password"
    RESULT=$(get_db shadow | awk -F: '($2 == "" ) { print $1 }')
    if [ -n "$RESULT" ]; then
        crit "Some accounts have an empty password"
        crit "$RESULT"
    else
        ok "All accounts have a password"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    RESULT=$(get_db shadow | awk -F: '($2 == "" ) { print $1 }')
    if [ -n "$RESULT" ]; then
        warn "Some accounts have an empty password"
        for ACCOUNT in $RESULT; do
            info "Locking $ACCOUNT"
            passwd -l "$ACCOUNT" >/dev/null 2>&1
        done
    else
        ok "All accounts have a password"
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
