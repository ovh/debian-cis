#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# Hardening script skeleton replace this line with proper point treated
#

set -e # One error, it's over
set -u # One variable unset, it's over

PATTERN='NX[[:space:]]\(Execute[[:space:]]Disable\)[[:space:]]protection:[[:space:]]active'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_pattern_exists_in_dmesg $PATTERN
    if [ $FNRET != 0 ]; then
        crit "$PATTERN not present in dmesg"
    else
        ok "$PATTERN present in dmesg"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    does_pattern_exists_in_dmesg $PATTERN
    if [ $FNRET != 0 ]; then
        crit "$PATTERN not present in dmesg, please go to the bios to activate this option or change for CPU compatible"
    else
        ok "$PATTERN present in dmesg"
    fi
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
