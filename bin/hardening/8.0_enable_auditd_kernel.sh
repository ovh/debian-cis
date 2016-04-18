#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 8.0 Ensure CONFIG_AUDIT is enabled in your running kernel
#

set -e # One error, it's over
set -u # One variable unset, it's over

# Note : Not part of the CIS guide, but what's the point configuring a software not compatible with your kernel ? :)

KERNEL_OPTION="CONFIG_AUDIT"


# This function will be called if the script status is on enabled / audit mode
audit () {
    is_kernel_option_enabled "^$KERNEL_OPTION="
    if [ $FNRET = 0 ]; then # 0 means true in bash, so it IS activated
        ok "$KERNEL_OPTION is enabled"
    else
        crit "$KERNEL_OPTION is disabled, auditd will not work"
    fi
    :
}

# This function will be called if the script status is on enabled mode
apply () {
    is_kernel_option_enabled "^$KERNEL_OPTION="
    if [ $FNRET = 0 ]; then # 0 means true in bash, so it IS activated
        ok "$KERNEL_OPTION is enabled"
    else
        warn "I cannot fix $KERNEL_OPTION disabled, to make auditd work, recompile your kernel please"
    fi
    :
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
