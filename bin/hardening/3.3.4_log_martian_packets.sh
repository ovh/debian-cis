#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 3.3.4 Ensure suspicious packets are logged (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Log suspicious packets, like spoofed packets."

SYSCTL_PARAMS='net.ipv4.conf.all.log_martians=1 net.ipv4.conf.default.log_martians=1'

# This function will be called if the script status is on enabled / audit mode
audit() {
    for SYSCTL_VALUES in $SYSCTL_PARAMS; do
        SYSCTL_PARAM=$(echo "$SYSCTL_VALUES" | cut -d= -f 1)
        SYSCTL_EXP_RESULT=$(echo "$SYSCTL_VALUES" | cut -d= -f 2)
        debug "$SYSCTL_PARAM should be set to $SYSCTL_EXP_RESULT"
        has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
        if [ "$FNRET" != 0 ]; then
            crit "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT"
        elif [ "$FNRET" = 255 ]; then
            warn "$SYSCTL_PARAM does not exist -- Typo?"
        else
            ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    for SYSCTL_VALUES in $SYSCTL_PARAMS; do
        SYSCTL_PARAM=$(echo "$SYSCTL_VALUES" | cut -d= -f 1)
        SYSCTL_EXP_RESULT=$(echo "$SYSCTL_VALUES" | cut -d= -f 2)
        debug "$SYSCTL_PARAM should be set to $SYSCTL_EXP_RESULT"
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
