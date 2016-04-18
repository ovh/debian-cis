#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 4.3 Enable Randomized Virtual Memory Region Placement (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

SYSCTL_PARAM='kernel.randomize_va_space'
SYSCTL_EXP_RESULT=2

# This function will be called if the script status is on enabled / audit mode
audit () {
    has_sysctl_param_expected_result $SYSCTL_PARAM $SYSCTL_EXP_RESULT
    if [ $FNRET != 0 ]; then
        crit "$SYSCTL_PARAM has not $SYSCTL_EXP_RESULT value !"
    elif [ $FNRET = 255 ]; then
        warn "$SYSCTL_PARAM does not exist, typo ?"
    else
        ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    has_sysctl_param_expected_result $SYSCTL_PARAM $SYSCTL_EXP_RESULT
    if [ $FNRET != 0 ]; then
        warn "$SYSCTL_PARAM has not $SYSCTL_EXP_RESULT value, correcting it"
        set_sysctl_param $SYSCTL_PARAM $SYSCTL_EXP_RESULT
    elif [ $FNRET = 255 ]; then
        warn "$SYSCTL_PARAM does not exist, typo ?"
    else
        ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardening ]; then
    echo "There is no /etc/default/cis-hardening file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardening
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
