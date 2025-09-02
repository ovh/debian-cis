#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure ufw outbound connections are configured (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure ufw outbound connections are configured"
UFW_RULES_FILE="/etc/ufw/user.rules"
# variable defined in config file
ALLOW_OUTBOUND_ALL=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    UFW_RULE_IS_VALID=1
    # rules are saved in /etc/ufw/user.rules
    # easier to parse than ufw output
    if $SUDO_CMD grep "^[^#]*-[A,I].*output -o all -j ACCEPT" "$UFW_RULES_FILE" >/dev/null 2>&1; then
        if [ "$ALLOW_OUTBOUND_ALL" -eq 0 ]; then
            UFW_RULE_IS_VALID=0
            ok "ufw output is allowed for all"
        else
            crit "ufw output is allowed for all, and ALLOW_OUTBOUND_ALL=1"
        fi
    else
        if [ "$ALLOW_OUTBOUND_ALL" -eq 1 ]; then
            UFW_RULE_IS_VALID=0
            ok "ufw output is not allowed for all"
        else
            crit "ufw output is not allowed for all, and ALLOW_OUTBOUND_ALL=0"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$UFW_RULE_IS_VALID" -ne 0 ]; then
        info "Please review the output rules according to your site policy, and update 'ALLOW_OUTBOUND_ALL' in configuration accordingly"
    fi
}

create_config() {
    cat <<EOF
# shellcheck disable=2034
status=audit
# ALLOW_OUTBOUND_ALL=0 means true, we want the rule to be present
# ALLOW_OUTBOUND_ALL=1 means false, we don't want the rule to be present
ALLOW_OUTBOUND_ALL=0
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
