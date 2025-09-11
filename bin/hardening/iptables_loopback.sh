#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure iptables loopback traffic is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure iptables loopback traffic is configured"
PACKAGE="iptables"

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" -ne 0 ]; then
        crit "$PACKAGE is not installed"
        return
    fi

    IPTABLES_LOOPBACK_INPUT=1
    IPTABLES_LOOPBACK_OUTPUT=1
    IPTABLES_LOOPBACK_DENY=1

    local input_rules
    local output_rules
    input_rules=$($SUDO_CMD iptables -S INPUT 2>/dev/null)
    output_rules=$($SUDO_CMD iptables -S OUTPUT 2>/dev/null)

    # the '.*' below is in case of comments
    # shellcheck disable=2086
    if grep "\-A INPUT -i lo.*-j ACCEPT" <<<$input_rules >/dev/null; then
        ok "loopback is configured in iptables input rules"
        IPTABLES_LOOPBACK_INPUT=0
    else
        crit "loopback is not configured in iptables input rules"
    fi

    # shellcheck disable=2086
    if grep "\-A INPUT -s 127.0.0.0/8.*-j DROP" <<<$input_rules >/dev/null; then
        ok "127.0.0.0/8 is dropped in iptables input rules"
        IPTABLES_LOOPBACK_DENY=0
    else
        crit "127.0.0.0/8 is not dropped in iptables input rules"
    fi

    # shellcheck disable=2086
    if grep "\-A OUTPUT -o lo.*-j ACCEPT" <<<$output_rules >/dev/null; then
        ok "loopback is configured in iptables output rules"
        IPTABLES_LOOPBACK_OUTPUT=0
    else
        crit "loopback is not configured in iptables output rules"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$IPTABLES_LOOPBACK_INPUT" -ne 0 ]; then
        info "update iptables rules to allow loopback input"
        iptables -A INPUT -i lo -j ACCEPT
    fi

    if [ "$IPTABLES_LOOPBACK_OUTPUT" -ne 0 ]; then
        info "update iptables rules to allow loopback" output
        iptables -A OUTPUT -o lo -j ACCEPT
    fi

    if [ "$IPTABLES_LOOPBACK_DENY" -ne 0 ]; then
        info "update iptables rules to drop 127.0.0.0/8 input"
        iptables -A INPUT -s 127.0.0.0/8 -j DROP
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
