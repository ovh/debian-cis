#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.1.1.7 Ensure mounting of FAT filesystems is limited (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=5
# shellcheck disable=2034
DESCRIPTION="Limit mounting of FAT filesystems."

# Note: we check /proc/config.gz to be compliant with both monolithic and modular kernels

KERNEL_OPTION="CONFIG_VFAT_FS"
MODULE_FILE="vfat"

# This function will be called if the script status is on enabled / audit mode
audit() {
    # TODO check if uefi enabled if yes check if only boot partition use FAT
    is_kernel_option_enabled "$KERNEL_OPTION" "$MODULE_FILE"
    if [ "$FNRET" = 0 ]; then # 0 means true in bash, so it IS activated
        crit "$KERNEL_OPTION is enabled!"
    else
        ok "$KERNEL_OPTION is disabled"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    is_kernel_option_enabled "$KERNEL_OPTION"
    if [ "$FNRET" = 0 ]; then # 0 means true in bash, so it IS activated
        warn "I cannot fix $KERNEL_OPTION enabled, recompile your kernel please"
    else
        ok "$KERNEL_OPTION is disabled, nothing to do"
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
