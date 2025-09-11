#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure ip6tables loopback traffic is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure ip6tables loopback traffic is configured"
PACKAGE="iptables"

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

    IPTABLES_LOOPBACK_INPUT=1
    IPTABLES_LOOPBACK_OUTPUT=1
    IPTABLES_LOOPBACK_DENY=1

    local input_rules
    local output_rules
    input_rules=$($SUDO_CMD ip6tables -S INPUT 2>/dev/null)
    output_rules=$($SUDO_CMD ip6tables -S OUTPUT 2>/dev/null)

    # the '.*' below is in case of comments
    # shellcheck disable=2086
    if grep "\-A INPUT -i lo.*-j ACCEPT" <<<$input_rules >/dev/null; then
        ok "loopback is configured in ip6tables input rules"
        IPTABLES_LOOPBACK_INPUT=0
    else
        crit "loopback is not configured in ip6tables input rules"
    fi

    # shellcheck disable=2086
    if grep "\-A INPUT -s ::1 .*-j DROP" <<<$input_rules >/dev/null; then
        ok "::1 is dropped in ip6tables input rules"
        IPTABLES_LOOPBACK_DENY=0
    else
        crit "::1 is not dropped in ip6tables input rules"
    fi

    # shellcheck disable=2086
    if grep "\-A OUTPUT -o lo.*-j ACCEPT" <<<$output_rules >/dev/null; then
        ok "loopback is configured in ip6tables output rules"
        IPTABLES_LOOPBACK_OUTPUT=0
    else
        crit "loopback is not configured in ip6tables output rules"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$IPTABLES_LOOPBACK_INPUT" -ne 0 ]; then
        info "update ip6tables rules to allow loopback input"
        ip6tables -A INPUT -i lo -j ACCEPT
    fi

    if [ "$IPTABLES_LOOPBACK_OUTPUT" -ne 0 ]; then
        info "update ip6tables rules to allow loopback" output
        ip6tables -A OUTPUT -o lo -j ACCEPT
    fi

    if [ "$IPTABLES_LOOPBACK_DENY" -ne 0 ]; then
        info "update ip6tables rules to drop ::1  input"
        ip6tables -A INPUT -s ::1 -j DROP
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
