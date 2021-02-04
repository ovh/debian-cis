#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.1.1.6 Ensure mounting of udf filesystems is disabled (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Disable mounting of udf filesystems."

KERNEL_OPTION="CONFIG_UDF_FS"
MODULE_NAME="udf"

# This function will be called if the script status is on enabled / audit mode
audit() {
    if [ "$IS_CONTAINER" -eq 1 ]; then
        # In an unprivileged container, the kernel modules are host dependent, so you should consider enforcing it
        ok "Container detected, consider host enforcing or disable this check!"
    else
        is_kernel_option_enabled "$KERNEL_OPTION" "$MODULE_NAME" "($MODULE_NAME|install)"
        if [ "$FNRET" = 0 ]; then # 0 means true in bash, so it IS activated
            crit "$MODULE_NAME is enabled!"
        else
            ok "$MODULE_NAME is disabled"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$IS_CONTAINER" -eq 1 ]; then
        # In an unprivileged container, the kernel modules are host dependent, so you should consider enforcing it
        ok "Container detected, consider host enforcing!"
    else
        is_kernel_option_enabled "$KERNEL_OPTION" "$MODULE_NAME" "($MODULE_NAME|install)"
        if [ "$FNRET" = 0 ]; then # 0 means true in bash, so it IS activated
            warn "I cannot fix $MODULE_NAME, recompile your kernel or blacklist module $MODULE_NAME (/etc/modprobe.d/blacklist.conf : +install $MODULE_NAME /bin/true)"
        else
            ok "$MODULE_NAME is disabled"
        fi
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
