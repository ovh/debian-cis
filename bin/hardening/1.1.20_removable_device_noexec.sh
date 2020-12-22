#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.1.20 Ensure noexec option set on removable media partition (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="noexec option for removable media partitions."

# Fair warning, it only checks /media.* like partition in fstab, it's not exhaustive

# Quick factoring as many script use the same logic
PARTITION="/media\S*"
OPTION="noexec"

# This function will be called if the script status is on enabled / audit mode
audit() {
    info "Verifying if there is $PARTITION like partition"
    FNRET=0
    is_a_partition "$PARTITION"
    if [ "$FNRET" -gt 0 ]; then
        ok "There is no partition like $PARTITION"
        FNRET=0
    else
        info "detected $PARTITION like"
        has_mount_option "$PARTITION" "$OPTION"
        if [ "$FNRET" -gt 0 ]; then
            crit "$PARTITION has no option $OPTION in fstab!"
            FNRET=1
        else
            ok "$PARTITION has $OPTION in fstab"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$FNRET" = 0 ]; then
        ok "$PARTITION is correctly set"
    elif [ "$FNRET" = 1 ]; then
        info "Adding $OPTION to fstab"
        add_option_to_fstab "$PARTITION" "$OPTION"
    fi
}

# This function will check config parameters required
check_config() {
    # No param for this script
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
