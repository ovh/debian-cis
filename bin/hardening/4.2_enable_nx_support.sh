#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 4.2 Enable XD/NX Support on 32-bit x86 Systems (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

PATTERN='NX[[:space:]]\(Execute[[:space:]]Disable\)[[:space:]]protection:[[:space:]]active'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_pattern_exist_in_dmesg $PATTERN
    if [ $FNRET != 0 ]; then
        crit "$PATTERN is not present in dmesg"
    else
        ok "$PATTERN is present in dmesg"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    does_pattern_exist_in_dmesg $PATTERN
    if [ $FNRET != 0 ]; then
        crit "$PATTERN is not present in dmesg, please go to the bios to activate this option or change for CPU compatible"
    else
        ok "$PATTERN is present in dmesg"
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
    if [ -z ${CIS_ROOT_DIR:-} ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
        exit 128
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r $CIS_ROOT_DIR/lib/main.sh ]; then
    . $CIS_ROOT_DIR/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
