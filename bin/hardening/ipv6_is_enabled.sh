#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure IPv6 status is identified (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure IPv6 status is identified"
IPV6_ENABLED=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_ipv6_enabled
    if [ "$FNRET" -eq 0 ] && [ "$IPV6_ENABLED" -eq 0 ]; then
        ok "ipv6 is enabled"
    elif [ "$FNRET" -eq 0 ] && [ "$IPV6_ENABLED" -eq 1 ]; then
        crit "ipv6 is enabled"
    elif [ "$FNRET" -eq 1 ] && [ "$IPV6_ENABLED" -eq 1 ]; then
        ok "ipv6 is disabled"
    elif [ "$FNRET" -eq 1 ] && [ "$IPV6_ENABLED" -eq 0 ]; then
        crit "ipv6 is disabled"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Enable or disable manually IPv6 in accordance with system requirements and local site policy"
}

create_config() {
    cat <<EOF
# shellcheck disable=2034
status=audit
# if ipv6 is supposed to be enabled -> IPV6_ENABLED=0
# if ipv6 is supposed to be disabled -> IPV6_ENABLED=1
IPV6_ENABLED=0
EOF
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
