#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure IP forwarding is disabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
HARDENING_EXCEPTION=gw
# shellcheck disable=2034
DESCRIPTION="Disable IP forwarding."

SYSCTL_PARAMS='net.ipv4.ip_forward net.ipv6.conf.all.forwarding'
SYSCTL_EXP_RESULT=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    for SYSCTL_PARAM in $SYSCTL_PARAMS; do
        does_sysctl_param_exists "net.ipv6"
        if [ "$FNRET" = 0 ] || [[ ! $SYSCTL_PARAM =~ .*ipv6.* ]]; then # IPv6 is enabled or SYSCTL_VALUES doesn't contain ipv6
            has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
            if [ "$FNRET" != 0 ]; then
                crit "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT"
            elif [ "$FNRET" = 255 ]; then
                warn "$SYSCTL_PARAM does not exist -- Typo?"
            else
                ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
            fi
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    for SYSCTL_PARAM in $SYSCTL_PARAMS; do
        has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
        if [ "$FNRET" != 0 ]; then
            warn "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT -- Fixing"
            set_sysctl_param "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
            sysctl -w net.ipv4.route.flush=1 >/dev/null
        elif [ "$FNRET" = 255 ]; then
            warn "$SYSCTL_PARAM does not exist -- Typo?"
        else
            ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
        fi
    done
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
