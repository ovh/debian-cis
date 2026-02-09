#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure user emulation is audited (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure audit rules for user emulation commands are configured."

AUDIT_RULES_FILE='/etc/audit/rules.d/50-user_emulation.rules'
AUDIT_PARAMS='-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation
-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation'

# Global state
RULES_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    RULES_OK=1

    if [ ! -f "$AUDIT_RULES_FILE" ]; then
        crit "Audit rules file $AUDIT_RULES_FILE does not exist"
        RULES_OK=0
        return
    fi

    # Check each rule
    while IFS= read -r rule; do
        if ! grep -qF "$rule" "$AUDIT_RULES_FILE"; then
            crit "Missing audit rule: $rule"
            RULES_OK=0
        fi
    done <<EOF
$AUDIT_PARAMS
EOF

    if [ "$RULES_OK" -eq 1 ]; then
        ok "User emulation audit rules are correctly configured"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$RULES_OK" -eq 0 ]; then
        info "Creating user emulation audit rules"
        mkdir -p "$(dirname "$AUDIT_RULES_FILE")"

        cat >"$AUDIT_RULES_FILE" <<EOF
## User emulation commands
$AUDIT_PARAMS
EOF

        # Load the rules
        info "Loading audit rules"
        augenrules --load || true
    else
        ok "User emulation audit rules already configured"
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
if [ -z "${CIS_LIB_DIR}" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
