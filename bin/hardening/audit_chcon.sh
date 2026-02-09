#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure use of chcon command is audited (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure audit rules for chcon command are configured."

AUDIT_RULES_FILE='/etc/audit/rules.d/50-perm_chng.rules'
UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

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

    # Check for chcon rules
    if ! grep -qE "chcon.*-k perm_chng" "$AUDIT_RULES_FILE"; then
        crit "chcon audit rule not found"
        RULES_OK=0
    else
        ok "chcon audit rules are correctly configured"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$RULES_OK" -eq 0 ]; then
        info "Creating chcon audit rules"
        mkdir -p "$(dirname "$AUDIT_RULES_FILE")"

        # Create or append to the file
        if [ ! -f "$AUDIT_RULES_FILE" ]; then
            cat >"$AUDIT_RULES_FILE" <<EOF
## Permission modification
EOF
        fi

        # Add chcon rules if not present
        if ! grep -q "chcon" "$AUDIT_RULES_FILE" 2>/dev/null; then
            cat >>"$AUDIT_RULES_FILE" <<EOF
-a always,exit -F path=/usr/bin/chcon -F perm=x -F auid>=$UID_MIN -F auid!=unset -k perm_chng
EOF
        fi

        # Load the rules
        info "Loading audit rules"
        augenrules --load || true
    else
        ok "chcon audit rules already configured"
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
