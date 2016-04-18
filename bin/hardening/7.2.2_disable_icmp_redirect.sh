#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 7.2.2 Disable ICMP Redirect Acceptance (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

SYSCTL_PARAMS='net.ipv4.conf.all.accept_redirects=0 net.ipv4.conf.default.accept_redirects=0'

# This function will be called if the script status is on enabled / audit mode
audit () {
    for SYSCTL_VALUES in $SYSCTL_PARAMS; do
        SYSCTL_PARAM=$(echo $SYSCTL_VALUES | cut -d= -f 1)
        SYSCTL_EXP_RESULT=$(echo $SYSCTL_VALUES | cut -d= -f 2)
        debug "$SYSCTL_PARAM must have $SYSCTL_EXP_RESULT"
        has_sysctl_param_expected_result $SYSCTL_PARAM $SYSCTL_EXP_RESULT
        if [ $FNRET != 0 ]; then
            crit "$SYSCTL_PARAM has not $SYSCTL_EXP_RESULT value !"
        elif [ $FNRET = 255 ]; then
            warn "$SYSCTL_PARAM does not exist, typo ?"
        else
            ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply () {
    for SYSCTL_VALUES in $SYSCTL_PARAMS; do
        SYSCTL_PARAM=$(echo $SYSCTL_VALUES | cut -d= -f 1)
        SYSCTL_EXP_RESULT=$(echo $SYSCTL_VALUES | cut -d= -f 2)
        debug "$SYSCTL_PARAM must have $SYSCTL_EXP_RESULT"
        has_sysctl_param_expected_result $SYSCTL_PARAM $SYSCTL_EXP_RESULT
        if [ $FNRET != 0 ]; then
            warn "$SYSCTL_PARAM has not $SYSCTL_EXP_RESULT value, correcting it"
            set_sysctl_param $SYSCTL_PARAM $SYSCTL_EXP_RESULT
            sysctl -w net.ipv4.route.flush=1 > /dev/null
        elif [ $FNRET = 255 ]; then
            warn "$SYSCTL_PARAM does not exist, typo ?"
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
if [ ! -r /etc/default/cis-hardenning ]; then
    echo "There is no /etc/default/cis-hardenning file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardenning
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
