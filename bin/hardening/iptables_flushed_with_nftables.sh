#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure iptables are flushed with nftables (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="if running nftables, we don't want to mix rules with iptables"
PACKAGE="nftables"

# This function will be called if the script status is on enabled / audit mode
audit() {
    IPTABLES_CHAIN_EMPTY=0

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" -eq 0 ]; then
        for chain in INPUT OUTPUT FORWARD; do
            # ex of empty INPUT chain: "-P INPUT ACCEPT"
            # shellcheck disable=2046
            if [ $($SUDO_CMD iptables -S "$chain" 2>/dev/null | wc -l) -gt 1 ]; then
                IPTABLES_CHAIN_EMPTY=1
                crit "nftables is installed, but iptables '$chain' rules are not empty"
            else
                ok "nftables is installed and iptables '$chain' rules are empty"
            fi
        done
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$IPTABLES_CHAIN_EMPTY" -ne 0 ]; then
        info "Please review the 'iptables' rules, and either move them to 'nftables', or disable this check"
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
