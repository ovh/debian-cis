#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.6.2 Ensure address space layout randomization (ASLR) is enabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Enable Randomized Virtual Memory Region Placement to prevent memory page exploits."

SYSCTL_PARAM='kernel.randomize_va_space'
SYSCTL_EXP_RESULT=2

# This function will be called if the script status is on enabled / audit mode
audit() {
    has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
    if [ "$FNRET" != 0 ]; then
        crit "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT"
    elif [ "$FNRET" = 255 ]; then
        warn "$SYSCTL_PARAM does not exist -- Typo?"
    else
        ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
    if [ "$FNRET" != 0 ]; then
        warn "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT -- Fixing"
        set_sysctl_param "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
    elif [ "$FNRET" = 255 ]; then
        warn "$SYSCTL_PARAM does not exist -- Typo?"
    else
        ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
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
