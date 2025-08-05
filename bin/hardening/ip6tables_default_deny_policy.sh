#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure ip6tables default deny firewall policy (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure ip6tables default deny firewall policy"

# This function will be called if the script status is on enabled / audit mode
audit() {
    INPUT_CHAIN_DROP=1
    OUTPUT_CHAIN_DROP=1
    FORWARD_CHAIN_DROP=1

    local input_default=""
    local output_default=""
    local forward_default=""
    input_default=$($SUDO_CMD ip6tables -S INPUT | awk '/^-P/ {print $3}')
    output_default=$($SUDO_CMD ip6tables -S OUTPUT | awk '/^-P/ {print $3}')
    forward_default=$($SUDO_CMD ip6tables -S FORWARD | awk '/^-P/ {print $3}')

    if [ "$input_default" != "DROP" ]; then
        crit "ip6tables 'INPUT' chain does not have 'DROP' has default policy"
    else
        ok "ip6tables 'input' chain has 'DROP' has default policy"
        INPUT_CHAIN_DROP=0
    fi

    if [ "$output_default" != "DROP" ]; then
        crit "ip6tables 'OUTPUT' chain does not have 'DROP' has default policy"
    else
        ok "ip6tables 'OUTPUT' chain has 'DROP' has default policy"
        OUTPUT_CHAIN_DROP=0
    fi

    if [ "$forward_default" != "DROP" ]; then
        crit "ip6tables 'FORWARD' chain does not have 'DROP' has default policy"
    else
        ok "ip6tables 'FORWARD' chain has 'DROP' has default policy"
        FORWARD_CHAIN_DROP=0
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$INPUT_CHAIN_DROP" -ne 0 ]; then
        info "Please review your ip6tables default 'INPUT' policy, we can't change it bindly"
    fi

    if [ "$OUTPUT_CHAIN_DROP" -ne 0 ]; then
        info "Please review your ip6tables default 'OUTPUT' policy, we can't change it bindly"
    fi

    if [ "$FORWARD_CHAIN_DROP" -ne 0 ]; then
        info "Please review your ip6tables default 'FORWARD' policy, we can't change it bindly"
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
