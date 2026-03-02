#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.3.3.2 Ensure actions as another user are always logged (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure actions as another user are always logged."

AUDIT_RULES_FILE='/etc/audit/rules.d/50-user_emulation.rules'

# Global state
AUE_RULES_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    # Check on-disk audit rules
    local on_disk_rules
    on_disk_rules=$(awk '/^ *-a *always,exit/ &&/ -F *arch=b(32|64)/ &&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) &&(/ -C *euid!=uid/||/ -C *uid!=euid/) &&/ -S *execve/ &&(/ key= *[!-~]* *$/||/ -k *[!-~]* *$/)' /etc/audit/rules.d/*.rules 2>/dev/null || true)

    # Check running audit rules
    local running_rules
    running_rules=$($SUDO_CMD auditctl -l 2>/dev/null | awk '/^ *-a *always,exit/ &&/ -F *arch=b(32|64)/ &&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) &&(/ -C *euid!=uid/||/ -C *uid!=euid/) &&/ -S *execve/ &&(/ key= *[!-~]* *$/||/ -k *[!-~]* *$/)' || true)

    # Count rules for b64 and b32 architectures
    local on_disk_b64
    local on_disk_b32
    local running_b64
    local running_b32
    on_disk_b64=$(echo "$on_disk_rules" | grep -c "arch=b64" || true)
    on_disk_b32=$(echo "$on_disk_rules" | grep -c "arch=b32" || true)
    running_b64=$(echo "$running_rules" | grep -c "arch=b64" || true)
    running_b32=$(echo "$running_rules" | grep -c "arch=b32" || true)

    # Validate that we have at least one rule for each architecture in both configurations
    if [ "$on_disk_b64" -ge 1 ] && [ "$on_disk_b32" -ge 1 ] && [ "$running_b64" -ge 1 ] && [ "$running_b32" -ge 1 ]; then
        ok "User emulation auditing is properly configured for both architectures"
        AUE_RULES_OK=0
    else
        if [ "$on_disk_b64" -lt 1 ] || [ "$on_disk_b32" -lt 1 ]; then
            crit "User emulation auditing is not properly configured in /etc/audit/rules.d/ (b64: $on_disk_b64, b32: $on_disk_b32)"
        fi
        if [ "$running_b64" -lt 1 ] || [ "$running_b32" -lt 1 ]; then
            crit "User emulation auditing is not properly loaded in running configuration (b64: $running_b64, b32: $running_b32)"
        fi
        AUE_RULES_OK=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$AUE_RULES_OK" -eq 0 ]; then
        ok "User emulation auditing is already configured"
        return
    fi

    # Create audit rules directory if needed
    if [ ! -d /etc/audit/rules.d ]; then
        info "Creating /etc/audit/rules.d directory"
        mkdir -p /etc/audit/rules.d
    fi

    # Remove existing user_emulation rules to avoid duplicates
    if [ -f "$AUDIT_RULES_FILE" ]; then
        sed -i '/user_emulation/d' "$AUDIT_RULES_FILE"
    fi

    # Create file with header if it doesn't exist
    if [ ! -f "$AUDIT_RULES_FILE" ]; then
        echo "# Audit rules for user emulation - CIS Benchmark" >"$AUDIT_RULES_FILE"
    fi

    # Add the audit rules for both architectures
    info "Adding user emulation audit rules to $AUDIT_RULES_FILE"
    echo "-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k user_emulation" >>"$AUDIT_RULES_FILE"
    echo "-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k user_emulation" >>"$AUDIT_RULES_FILE"

    # Load the rules
    info "Loading audit rules"
    augenrules --load
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
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_LIB_DIR in /etc/default/cis-hardening"
    exit 128
fi
