#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure iptables outbound and established connections are configured (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure iptables outbound and established connections are configured"
PACKAGE="iptables"

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" -ne 0 ]; then
        crit "$PACKAGE is not installed"
        return
    fi

    INPUT_ESTABLISHED=1
    OUTPUT_ESTABLISHED=1

    local output_established_rules

    if $SUDO_CMD iptables -S INPUT | grep ESTABLISHED >/dev/null 2>&1; then
        INPUT_ESTABLISHED=0
        ok "INPUT ESTABLISHED connections are allowed"
    else
        crit "INPUT ESTABLISHED connections are not allowed"
    fi

    if $SUDO_CMD iptables -S OUTPUT | grep state >/dev/null 2>&1; then
        output_established_rules=$($SUDO_CMD iptables -S OUTPUT | grep state)
        # shellcheck disable=2086
        if grep ESTABLISHED <<<$output_established_rules >/dev/null && grep NEW <<<$output_established_rules >/dev/null; then
            OUTPUT_ESTABLISHED=0
            ok "OUTPUT NEW and ESTABLISHED connections are allowed"
        else
            crit "OUTPUT NEW and ESTABLISHED connections are not allowed"
        fi
    else
        crit "OUTPUT NEW and ESTABLISHED connections are not allowed"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$INPUT_ESTABLISHED" -ne 0 ] || [ "$OUTPUT_ESTABLISHED" -ne 0 ]; then
        info "Please review manually your outbound and established connection, and update them accordingly to your site policies"
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
