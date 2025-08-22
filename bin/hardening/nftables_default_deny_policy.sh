#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure nftables default deny firewall policy (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure nftables default deny firewall policy "

# This function will be called if the script status is on enabled / audit mode
audit() {
    INPUT_CHAIN_DROP=1
    OUTPUT_CHAIN_DROP=1
    FORWARD_CHAIN_DROP=1

    if $SUDO_CMD nft list ruleset 2>/dev/null | grep "hook input.*policy drop"; then
        INPUT_CHAIN_DROP=0
        ok "nft base 'input' chain has 'drop' has default policy"
    else
        crit "nft base 'input' chain does not have 'drop' has default policy"
    fi

    if $SUDO_CMD nft list ruleset 2>/dev/null | grep 'hook output.*policy drop'; then
        OUTPUT_CHAIN_DROP=0
        ok "nft base 'output' chain has 'drop' has default policy"
    else
        crit "nft base 'output' chain does not have 'drop' has default policy"
    fi

    if $SUDO_CMD nft list ruleset 2>/dev/null | grep 'hook forward.*policy drop'; then
        FORWARD_CHAIN_DROP=0
        ok "nft base 'forward' chain has 'drop' has default policy"
    else
        crit "nft base 'forward' chain does not have 'drop' has default policy"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$INPUT_CHAIN_DROP" -ne 0 ]; then
        info "Please review your default 'input' policy."
    fi

    if [ "$OUTPUT_CHAIN_DROP" -ne 0 ]; then
        info "Please review your default 'output' policy."
    fi

    if [ "$FORWARD_CHAIN_DROP" -ne 0 ]; then
        info "Please review your default 'forward' policy."
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
