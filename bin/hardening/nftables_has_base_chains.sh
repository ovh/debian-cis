#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure nftables base chains exist (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure nftables base chains exist"

# This function will be called if the script status is on enabled / audit mode
audit() {
    INPUT_CHAIN=1
    OUTPUT_CHAIN=1
    FORWARD_CHAIN=1

    if $SUDO_CMD nft list ruleset 2>/dev/null | grep 'hook input'; then
        INPUT_CHAIN=0
        ok "nft base 'input' chain exist"
    else
        crit "nft base 'input' chain does not exist"
    fi

    if $SUDO_CMD nft list ruleset 2>/dev/null | grep 'hook output'; then
        OUTPUT_CHAIN=0
        ok "nft base 'output' chain exist"
    else
        crit "nft base 'output' chain does not exist"
    fi

    if $SUDO_CMD nft list ruleset 2>/dev/null | grep 'hook forward'; then
        FORWARD_CHAIN=0
        ok "nft base 'forward' chain exist"
    else
        crit "nft base 'forward' chain does not exist"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$INPUT_CHAIN" -eq 1 ]; then
        info "adding nft base input chain"
        # shellcheck disable=1083
        nft create chain inet filter input { type filter hook input priority 0 \;}
    fi

    if [ "$OUTPUT_CHAIN" -eq 1 ]; then
        info "adding nft base output chain"
        # shellcheck disable=1083
        nft create chain inet filter output { type filter hook output priority 0 \;}
    fi

    if [ "$FORWARD_CHAIN" -eq 1 ]; then
        info "adding nft base forward chain"
        # shellcheck disable=1083
        nft create chain inet filter forward { type filter hook forward priority 0 \;}
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
