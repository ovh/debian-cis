#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure ptrace_scope is restricted (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure ptrace_scope is restricted"

SYSCTL_PARAM='kernel.yama.ptrace_scope'
SYSCTL_VALUE=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    SYSCTL_VALID=1
    has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_VALUE"
    if [ "$FNRET" -ne 0 ]; then
        crit "$SYSCTL_PARAM is not set to $SYSCTL_VALUE"
    else
        ok "$SYSCTL_PARAM correctly set to $SYSCTL_VALUE"
        SYSCTL_VALID=0
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SYSCTL_VALID" -ne 0 ]; then
        info "setting $SYSCTL_PARAM=$SYSCTL_VALUE"
        set_sysctl_param "$SYSCTL_PARAM" "$SYSCTL_VALUE"
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
if [ -z "$CIS_LIB_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_LIB_DIR in /etc/default/cis-hardening"
    exit 128
fi
