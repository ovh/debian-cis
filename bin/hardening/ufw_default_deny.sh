#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure ufw default deny firewall policy (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure ufw default deny firewall policy"
UFW_DEFAULT_RULES_FILE="/etc/default/ufw"

# This function will be called if the script status is on enabled / audit mode
audit() {
    UFW_INPUT_DEFAULT_VALID=1
    UFW_OUTPUT_DEFAULT_VALID=1
    UFW_FORWARD_DEFAULT_VALID=1

    # ufw default rules are configured in /etc/default/ufw
    # easier to parse than ufw output
    local default_policy
    default_policy=$(awk -F '=' '/^[^#]*DEFAULT_INPUT_POLICY/ {print $2}' "$UFW_DEFAULT_RULES_FILE" | sed 's/\"//g')
    if [ "$default_policy" != "DROP" ]; then
        crit "ufw default input policy is $default_policy instead of DROP"
    else
        ok "ufw default input policy is $default_policy"
        UFW_INPUT_DEFAULT_VALID=0
    fi

    default_policy=$(awk -F '=' '/^[^#]*DEFAULT_OUTPUT_POLICY/ {print $2}' "$UFW_DEFAULT_RULES_FILE" | sed 's/\"//g')
    if [ "$default_policy" != "DROP" ]; then
        crit "ufw default output policy is $default_policy instead of DROP"
    else
        ok "ufw default output policy is $default_policy"
        UFW_OUTPUT_DEFAULT_VALID=0
    fi

    default_policy=$(awk -F '=' '/^[^#]*DEFAULT_FORWARD_POLICY/ {print $2}' "$UFW_DEFAULT_RULES_FILE" | sed 's/\"//g')
    if [ "$default_policy" != "DROP" ]; then
        crit "ufw default forward policy is $default_policy instead of DROP"
    else
        ok "ufw default forward policy is $default_policy"
        UFW_FORWARD_DEFAULT_VALID=0
    fi

    if [ "$UFW_INPUT_DEFAULT_VALID" -ne 0 ] || [ "$UFW_OUTPUT_DEFAULT_VALID" -ne 0 ] || [ "$UFW_FORWARD_DEFAULT_VALID" -ne 0 ]; then
        warn "Applying the recommendation will change the default policies to DROP, make sure you have set up the required rules"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$UFW_INPUT_DEFAULT_VALID" -ne 0 ]; then
        info "changing default input policy to DROP"
        ufw default deny incoming
    fi

    if [ "$UFW_OUTPUT_DEFAULT_VALID" -ne 0 ]; then
        info "changing default output policy to DROP"
        ufw default deny outgoing
    fi

    if [ "$UFW_FORWARD_DEFAULT_VALID" -ne 0 ]; then
        info "changing default forward policy to DROP"
        ufw default deny routed
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
