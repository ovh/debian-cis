#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 3.1.1 Disable IPv6 (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Disable IPv6."

SYSCTL_PARAMS='net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1 net.ipv6.conf.lo.disable_ipv6=1'

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_ipv6_enabled
    if [ "$FNRET" != 0 ]; then
        ok "ipv6 is disabled"
    else
        crit "ipv6 is enabled"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_ipv6_enabled
    if [ "$FNRET" != 0 ]; then
        ok "ipv6 is disabled"
    else
        for SYSCTL_VALUES in $SYSCTL_PARAMS; do
            SYSCTL_PARAM=$(echo "$SYSCTL_VALUES" | cut -d= -f 1)
            SYSCTL_EXP_RESULT=$(echo "$SYSCTL_VALUES" | cut -d= -f 2)
            debug "$SYSCTL_PARAM should be set to $SYSCTL_EXP_RESULT"
            has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
            if [ "$FNRET" != 0 ]; then
                warn "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT value, fixing"
                set_sysctl_param "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
                warn "you may want to reboot or sysctl -p a file including $SYSCTL_PARAMS"
            elif [ "$FNRET" = 255 ]; then
                warn "$SYSCTL_PARAM does not exist -- Typo?"
            else
                ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
            fi
        done
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
