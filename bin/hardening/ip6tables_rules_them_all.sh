#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure ip6tables firewall rules exist for all open ports (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure ip6tables firewall rules exist for all open ports"
PACKAGE="iptables"

# we are going to
# - list listening ports
# - list ip6tables rules using dport
# - compare both

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" -ne 0 ]; then
        crit "$PACKAGE is not installed"
        return
    fi

    is_ipv6_enabled
    if [ "$FNRET" -ne 0 ]; then
        ok "ipv6 is not enabled"
        return
    fi

    IPTABLES_IS_VALID=0
    local iptables_ports_rules=""
    local listening_ports
    # we may have configured some custom chains in INPUT, that need to be checked too.
    local custom_chains=""
    local builtin_targets="ACCEPT DROP QUEUE RETURN"

    for target in $($SUDO_CMD ip6tables -L INPUT | awk '{print $1}' | sed '1,2d'); do
        if ! grep "$target" <<<"$builtin_targets" >/dev/null; then
            custom_chains="$custom_chains $target"
        fi
    done

    for chain in INPUT $custom_chains; do
        # number of fields is not fixed, there may be some comments before and after
        # ex:
        # udp spt:68 dpt:67 /* DHCP Request */
        # /* ssh connection */ tcp dpt:22
        iptables_ports_rules="$iptables_ports_rules $($SUDO_CMD ip6tables -nL "$chain" | grep 'dpt:' | sed 's/^.*dpt://g' | awk '{print $1}' | sort -u)"
    done
    listening_ports=$($SUDO_CMD ss -tuln | awk '($5!~/%lo:/ && $5!~/127.0.0.1:/ && $5!~/\[?::1\]?:/) {split($5, a, ":"); print a[2]}' | sort -u)

    for port in $listening_ports; do
        if ! grep "$port" <<<"$iptables_ports_rules" >/dev/null; then
            crit "$port does not have an ip6tables rule"
            IPTABLES_IS_VALID=1
        fi
    done

    if [ "$IPTABLES_IS_VALID" -eq 0 ]; then
        ok "all listening ports have a corresponding rule in ufw"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$IPTABLES_IS_VALID" -ne 0 ]; then
        # Debian 12 CIS marks this script as "Automated", but we wont do it
        # How can we know if a rule should be allowed or denied ? From everywhere ? A specific range ?
        warn "Please review the ip6tables rules and update them accordingly. We wont do it in an automated way, as we don't know if it should be allowed or denied"
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
