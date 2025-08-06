#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure mounting of udf filesystems is disabled (Scored)
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
        is_kernel_module_loaded "$KERNEL_OPTION" "$MODULE_NAME"
        if [ "$FNRET" -eq 0 ]; then # 0 means true in bash, so it IS activated
            crit "$MODULE_NAME is loaded!"
        else
            ok "$MODULE_NAME is not loaded"
        fi

        if [ "$IS_MONOLITHIC_KERNEL" -eq 1 ]; then
            is_kernel_module_disabled "$MODULE_NAME"
            if [ "$FNRET" -eq 0 ]; then
                ok "$MODULE_NAME is disabled in the modprobe configuration"
            else
                is_kernel_module_available "$KERNEL_OPTION"
                if [ "$FNRET" -eq 0 ]; then
                    crit "$MODULE_NAME is available in some kernel config, but not disabled"
                else
                    ok "$MODULE_NAME is not available in any kernel config"
                fi
            fi
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$IS_CONTAINER" -eq 1 ]; then
        # In an unprivileged container, the kernel modules are host dependent, so you should consider enforcing it
        ok "Container detected, consider host enforcing!"
    else
        is_kernel_module_loaded "$KERNEL_OPTION" "$LOADED_MODULE_NAME"
        if [ "$FNRET" -eq 0 ]; then # 0 means true in bash, so it IS activated
            crit "$LOADED_MODULE_NAME is loaded!"
            warn "I wont unload the module, unload it manually or recompile the kernel if needed"
        fi

        if [ "$IS_MONOLITHIC_KERNEL" -eq 1 ]; then
            is_kernel_module_disabled "$MODULE_NAME"
            if [ "$FNRET" -eq 1 ]; then
                echo "install $MODULE_NAME /bin/true" >>/etc/modprobe.d/"$MODULE_NAME".conf
                info "$MODULE_NAME has been disabled in the modprobe configuration"
            fi
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
if [ -z "$CIS_LIB_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_LIB_DIR in /etc/default/cis-hardening"
    exit 128
fi
