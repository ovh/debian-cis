#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.7.1.3 Ensure all AppArmor profiles are in enforce or complain mode (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Enforce or complain AppArmor profiles."

PACKAGES='apparmor apparmor-utils'

# This function will be called if the script status is on enabled / audit mode
audit() {
    ERROR=0
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" != 0 ]; then
            crit "$PACKAGE is absent!"
            ERROR=1
        else
            ok "$PACKAGE is installed"
        fi
    done
    if [ "$ERROR" = 0 ]; then
        RESULT_UNCONFINED=$($SUDO_CMD apparmor_status | grep "^0 processes are unconfined but have a profile defined")

        if [ -n "$RESULT_UNCONFINED" ]; then
            ok "No profiles are unconfined"

        else
            crit "Some processes are unconfined while they have defined profile"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" != 0 ]; then
            crit "$PACKAGES is absent!"
            apt_install "$PACKAGE"
        else
            ok "$PACKAGE is installed"
        fi
    done

    RESULT_UNCONFINED=$(apparmor_status | grep "^0 processes are unconfined but have a profile defined")

    if [ -n "$RESULT_UNCONFINED" ]; then
        ok "No profiles are unconfined"
    else
        warn "Some processes are unconfined while they have defined profile, setting profiles to complain mode"
        aa-complain /etc/apparmor.d/*
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
