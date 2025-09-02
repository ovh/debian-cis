#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure ufw firewall rules exist for all open ports (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure ufw firewall rules exist for all open ports"

# This function will be called if the script status is on enabled / audit mode
audit() {
    UFW_IS_VALID=0
    local ufw_ports_rules
    local listening_ports

    ufw_ports_rules=$($SUDO_CMD ufw status verbose 2>/dev/null | grep -Po '^\h*\d+\b' | sort -u)
    listening_ports=$($SUDO_CMD ss -tuln | awk '($5!~/%lo:/ && $5!~/127.0.0.1:/ && $5!~/\[?::1\]?:/) {split($5, a, ":"); print a[2]}' | sort -u)

    for port in $listening_ports; do
        if ! grep "$port" <<<"$ufw_ports_rules"; then
            crit "$port does not have an ufw rule"
            UFW_IS_VALID=1
        fi
    done

    if [ "$UFW_IS_VALID" -eq 0 ]; then
        ok "all listening ports have a corresponding rule in ufw"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$UFW_IS_VALID" -ne 0 ]; then
        # Debian 12 CIS marks this script as "Automated", but we wont do it
        # How can we know if a rule should be allowed or denied ?
        warn "Please review the ufw rules and update them accordingly"
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
