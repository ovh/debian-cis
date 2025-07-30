#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure wireless interfaces are disabled (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure wireless interfaces are disabled"

# This function will be called if the script status is on enabled / audit mode
audit() {
    AVAILABLE_MODULES=""

    wireless_drivers=$(find /sys/class/net/*/ -type d -name wireless)
    if [ "$(wc -w <<<"$wireless_drivers")" -gt 0 ]; then
        # not the most readable syntax, took as is from the CIS pdf (just changed the vars name)
        for module in $(for wireless_driver in $(find /sys/class/net/*/ -type d -name wireless | xargs -0 dirname); do readlink -f "$wireless_driver"/device/driver/module; done); do

            is_kernel_module_available "$module"
            if [ "$FNRET" -eq 0 ]; then
                # is available in kernel config, but may be disabled in modprobe
                is_kernel_module_disabled "$module"
                if [ "$FNRET" -eq 1 ]; then
                    AVAILABLE_MODULES="$AVAILABLE_MODULES $module"
                fi
            fi
        done
    fi

    if [ -n "$AVAILABLE_MODULES" ]; then
        crit "There are some wireless modules available: $AVAILABLE_MODULES"
    else
        ok "There are no wireless modules available"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    for module in $AVAILABLE_MODULES ]; do
        echo "install $module /bin/true" >>/etc/modprobe.d/"$module".conf
        info "$module has been disabled in modprobe configuration"
    done
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
