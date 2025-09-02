#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure ufw loopback traffic is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure ufw loopback traffic is configured"
UFW_RULES_FILE="/etc/ufw/user.rules"
UFW_IPV6_RULES_FILE="/etc/ufw/user6.rules"

# This function will be called if the script status is on enabled / audit mode
audit() {
    UFW_LOOPBACK_INPUT=1
    UFW_LOOPBACK_OUTPUT=1
    UFW_LOOPBACK_DENY=1
    UFW_LOOPBACK_DENY_IPV6=1

    # rules are saved in /etc/ufw/user.rules
    # easier to parse than ufw output
    if $SUDO_CMD grep "^[^#]*-[A,I].*input -i lo -j ACCEPT" "$UFW_RULES_FILE" >/dev/null 2>&1; then
        UFW_LOOPBACK_INPUT=0
        ok "ufw loopback input is configured"
    else
        crit "ufw loopback input is not configured"
    fi

    if $SUDO_CMD grep "^[^#]*-[A,I].*output -o lo -j ACCEPT" "$UFW_RULES_FILE" >/dev/null 2>&1; then
        UFW_LOOPBACK_OUTPUT=0
        ok "ufw loopback output is configured"
    else
        crit "ufw loopback output is not configured"
    fi

    if $SUDO_CMD grep "^[^#]*-[A,I].*input -s 127.0.0.0/8 -j DROP" "$UFW_RULES_FILE" >/dev/null 2>&1; then
        UFW_LOOPBACK_DENY=0
        ok "ufw traffic from 127.0.0.0/8 is dropped"
    else
        crit "ufw traffic 127.0.0.0/8 is not dropped"
    fi

    is_ipv6_enabled
    if [ "$FNRET" -eq 0 ]; then
        if $SUDO_CMD grep "^[^#]*-[A,I].*input -s ::1 -j DROP" "$UFW_IPV6_RULES_FILE" >/dev/null 2>&1; then
            UFW_LOOPBACK_DENY_IPV6=0
            ok "ufw traffic from ipv6 ::1 is dropped"
        else
            crit "ufw traffic from ipv6 ::1 is not dropped"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$UFW_LOOPBACK_INPUT" -ne 0 ]; then
        info "adding ufw rule to allow loopback input"
        ufw allow in on lo
    fi

    if [ "$UFW_LOOPBACK_OUTPUT" -ne 0 ]; then
        info "adding ufw rule to allow loopback output"
        ufw allow out on lo
    fi

    if [ "$UFW_LOOPBACK_DENY" -ne 0 ]; then
        info "adding ufw rule to drop traffic from 127.0.0.0/8"
        ufw ufw deny in from 127.0.0.0/8
    fi

    is_ipv6_enabled
    if [ "$FNRET" -eq 0 ] && [ "$UFW_LOOPBACK_DENY_IPV6" -ne 0 ]; then
        info "adding ufw rule to drop traffic from ::1"
        ufw ufw deny in from ::1
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
