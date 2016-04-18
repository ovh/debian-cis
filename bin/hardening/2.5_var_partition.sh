#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 2.5 Create Separate Partition for /var (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# Quick factoring as many script use the same logic
PARTITION="/var"

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Verifying that $PARTITION is a partition"
    FNRET=0
    is_a_partition "$PARTITION"
    if [ $FNRET -gt 0 ]; then
        crit "$PARTITION is not a partition"
        FNRET=2
    else
        ok "$PARTITION is a partition"
        is_mounted "$PARTITION"
        if [ $FNRET -gt 0 ]; then
            warn "$PARTITION is not mounted"
            FNRET=1
        else
            ok "$PARTITION is mounted"
        fi
    fi
     
    :
}

# This function will be called if the script status is on enabled mode
apply () {
    if [ $FNRET = 0 ]; then
        ok "$PARTITION is correctly set"
    elif [ $FNRET = 2 ]; then
        crit "$PARTITION is not a partition, correct this by yourself, I cannot help you here"
    else
        info "mounting $PARTITION"
        mount $PARTITION
    fi
}

# This function will check config parameters required
check_config() {
    # No parameter for this script
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
