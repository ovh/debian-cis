#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 7.1.1 Disable IP Forwarding (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3
HARDENING_EXCEPTION=gw

SYSCTL_PARAM='net.ipv4.ip_forward'
SYSCTL_EXP_RESULT=0

# This function will be called if the script status is on enabled / audit mode
audit () {
    has_sysctl_param_expected_result $SYSCTL_PARAM $SYSCTL_EXP_RESULT
    if [ $FNRET != 0 ]; then
        crit "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT"
    elif [ $FNRET = 255 ]; then
        warn "$SYSCTL_PARAM does not exist -- Typo?"
    else
        ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    has_sysctl_param_expected_result $SYSCTL_PARAM $SYSCTL_EXP_RESULT
    if [ $FNRET != 0 ]; then
        warn "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT -- Fixing"
        set_sysctl_param $SYSCTL_PARAM $SYSCTL_EXP_RESULT
        sysctl -w net.ipv4.route.flush=1 > /dev/null
    elif [ $FNRET = 255 ]; then
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
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
     echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
     echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r $CIS_ROOT_DIR/lib/main.sh ]; then
    . $CIS_ROOT_DIR/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
