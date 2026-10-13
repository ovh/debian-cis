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

WIRELESS_SYS_CLASS_NET="/sys/class/net"
WIRELESS_MODPROBE_DIR="/etc/modprobe.d"
WIRELESS_MODULES=()

# A driver attached to an existing wireless interface is already active. A
# modprobe blacklist does not disable that interface or unload its driver.
audit() {
    local interface module_path module
    local -A seen=()
    WIRELESS_MODULES=()
    if [ ! -d "$WIRELESS_SYS_CLASS_NET" ]; then
        crit "Cannot inspect network interfaces: $WIRELESS_SYS_CLASS_NET is missing"
        return
    fi
    for interface in "$WIRELESS_SYS_CLASS_NET"/*; do
        if [ ! -d "$interface/wireless" ]; then
            continue
        fi
        if ! module_path=$(readlink -e -- "$interface/device/driver/module"); then
            crit "Cannot identify a loadable driver for wireless interface ${interface##*/}; disable it manually"
            continue
        fi
        module=${module_path##*/}
        if [[ ! "$module" =~ ^[[:alnum:]_-]+$ ]]; then
            crit "Invalid wireless module name for ${interface##*/}"
            continue
        fi
        crit "Wireless interface ${interface##*/} has active driver $module"
        if [ -z "${seen[$module]:-}" ]; then
            WIRELESS_MODULES+=("$module")
            seen[$module]=1
        fi
    done
    if [ "${#WIRELESS_MODULES[@]}" -eq 0 ]; then
        info "No loadable wireless drivers identified; unresolved interfaces require manual review"
    fi
}

# Configure future loads only: unloading a live driver can interrupt connectivity.
# The audit continues to fail while a wireless interface remains present.
apply() {
    local module config rule
    for module in "${WIRELESS_MODULES[@]}"; do
        mkdir -p -- "$WIRELESS_MODPROBE_DIR"
        config="$WIRELESS_MODPROBE_DIR/cis-wireless-$module.conf"
        for rule in "install $module /bin/false" "blacklist $module"; do
            if [ ! -f "$config" ] || ! grep -qxF -- "$rule" "$config"; then
                printf '%s\n' "$rule" >>"$config"
            fi
        done
        info "$module is blocked for future loads; reboot or disable the active interface manually"
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
