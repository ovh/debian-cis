#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure nftables loopback traffic is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure nftables loopback traffic is configured"

# This function will be called if the script status is on enabled / audit mode
audit() {
    NFTABLES_LOOPBACK=1
    NFTABLES_LOOPBACK_DROP=1
    NFTABLES_IPV6_LOOPBACK_DROP=1

    if nft list ruleset 2>/dev/null | awk '/hook input/,/}/' | grep 'iif "lo" accept'; then
        NFTABLES_LOOPBACK=0
        ok "loopback is configured for nftables"
    else
        crit "loopback is not configured for nftables"
    fi

    if nft list ruleset 2>/dev/null | awk '/hook input/,/}/' | grep "ip saddr 127.0.0.1.*drop"; then
        NFTABLES_LOOPBACK_DROP=0
        ok "nftables input loopack traffic is dropped"
    else
        crit "nftables input loopack traffic is not dropped"
    fi

    is_ipv6_enabled
    if [ "$FNRET" -eq 0 ]; then
        if nft list ruleset 2>/dev/null | awk '/hook input/,/}/' | grep "ip6 saddr ::1.*drop"; then
            NFTABLES_IPV6_LOOPBACK_DROP=0
            ok "nftables input loopack traffic is dropped"
        else
            crit "nftables input loopack traffic is not dropped"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$NFTABLES_LOOPBACK" -ne 0 ]; then
        info "adding nftables loopback configuration"
        nft add rule inet filter input iif lo accept
    fi

    if [ "$NFTABLES_LOOPBACK_DROP" -ne 0 ]; then
        info "adding nftables loopback drop configuration"
        nft create rule inet filter input ip saddr 127.0.0.0/8 counter drop
    fi

    is_ipv6_enabled
    if [ "$FNRET" -eq 0 ] && [ "$NFTABLES_IPV6_LOOPBACK_DROP" -ne 0 ]; then
        info "adding nftables ipv6 loopback drop configuration"
        nft add rule inet filter input ip6 saddr ::1 counter drop
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
