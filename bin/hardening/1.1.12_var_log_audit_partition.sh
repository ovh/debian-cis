#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.1.12 Ensure separate partition exists for /var/log/audit (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="/var/log/audit on a separate partition."

# Quick factoring as many script use the same logic
PARTITION="/var/log/audit"

# This function will be called if the script status is on enabled / audit mode
audit() {
    info "Verifying that $PARTITION is a partition"
    FNRET=0
    is_a_partition "$PARTITION"
    if [ "$FNRET" -gt 0 ]; then
        crit "$PARTITION is not a partition"
        FNRET=2
    else
        ok "$PARTITION is a partition"
        is_mounted "$PARTITION"
        if [ "$FNRET" -gt 0 ]; then
            warn "$PARTITION is not mounted"
            FNRET=1
        else
            ok "$PARTITION is mounted"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$FNRET" = 0 ]; then
        ok "$PARTITION is correctly set"
    elif [ "$FNRET" = 2 ]; then
        crit "$PARTITION is not a partition, correct this by yourself, I cannot help you here"
    else
        info "mounting $PARTITION"
        mount "$PARTITION"
    fi
}

# This function will check config parameters required
check_config() {
    # No parameter for this script
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
