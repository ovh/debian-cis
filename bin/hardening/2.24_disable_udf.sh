#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 2.24 Disable Mounting of udf Filesystems (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# Assumption made : yu have a monolothic kernel with your config zipped in /proc/config.gz
KERNEL_OPTION="udf"


# This function will be called if the script status is on enabled / audit mode
audit () {
    is_kernel_option_enabled $KERNEL_OPTION
    if [ $FNRET = 0 ]; then # 0 means true in bash, so it IS activated
        crit "$KERNEL_OPTION is enabled !"
    else
        ok "$KERNEL_OPTION is disabled"
    fi
    :
}

# This function will be called if the script status is on enabled mode
apply () {
    is_kernel_option_enabled $KERNEL_OPTION
    if [ $FNRET = 0 ]; then # 0 means true in bash, so it IS activated
        warn "I cannot fix $KERNEL_OPTION enabled, recompile your kernel please"
    else
        ok "$KERNEL_OPTION is disabled, nothing to do"
    fi
    :
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
