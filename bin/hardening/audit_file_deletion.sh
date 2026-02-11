#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure file deletion events by users are collected
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure file deletion events are audited"

AUDIT_RULES_FILE="/etc/audit/rules.d/50-delete.rules"
AUDIT_RULES_DIR='/etc/audit/rules.d'

# Global state
AFD_RULES_OK=1
AFD_UID_MIN=""

# This function will be called if the script status is on enabled / audit mode
audit() {

    # Get UID_MIN
    AFD_UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    if [ -z "$AFD_UID_MIN" ]; then
        crit "Unable to determine UID_MIN from /etc/login.defs"
        return
    fi

    # Check on disk configuration
    local l_ondisk_result
    l_ondisk_result=$(awk "/^ *-a *always,exit/ &&/ -F *arch=b(32|64)/ &&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) &&/ -F *auid>=${AFD_UID_MIN}/ &&/ -S/ &&(/unlink/||/rename/||/unlinkat/||/renameat/) &&(/ key= *[!-~]* *$/||/ -k *[!-~]* *$/)" "$AUDIT_RULES_DIR"/*.rules 2>/dev/null || true)

    # Check running configuration
    local l_running_result
    l_running_result=$($SUDO_CMD auditctl -l 2>/dev/null | awk "/^ *-a *always,exit/ &&/ -F *arch=b(32|64)/ &&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) &&/ -F *auid>=${AFD_UID_MIN}/ &&/ -S/ &&(/unlink/||/rename/||/unlinkat/||/renameat/) &&(/ key= *[!-~]* *$/||/ -k *[!-~]* *$/)" || true)

    # We need both b64 and b32 rules in both configurations
    local l_ondisk_b64 l_ondisk_b32 l_running_b64 l_running_b32
    l_ondisk_b64=$(echo "$l_ondisk_result" | grep -c "b64" || true)
    l_ondisk_b32=$(echo "$l_ondisk_result" | grep -c "b32" || true)
    l_running_b64=$(echo "$l_running_result" | grep -c "b64" || true)
    l_running_b32=$(echo "$l_running_result" | grep -c "b32" || true)

    if [ "$l_ondisk_b64" -ge 1 ] && [ "$l_ondisk_b32" -ge 1 ] && [ "$l_running_b64" -ge 1 ] && [ "$l_running_b32" -ge 1 ]; then
        ok "File deletion events are correctly configured on disk and running"
        AFD_RULES_OK=0
    else
        if [ "$l_ondisk_b64" -eq 0 ] || [ "$l_ondisk_b32" -eq 0 ]; then
            crit "File deletion audit rules not found or incomplete in on-disk configuration"
        fi
        if [ "$l_running_b64" -eq 0 ] || [ "$l_running_b32" -eq 0 ]; then
            crit "File deletion audit rules not found or incomplete in running configuration"
        fi
        AFD_RULES_OK=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$(id -u)" -ne 0 ]; then
        crit "This function must be run as root (current user: $(whoami))"
        return 1
    fi

    if [ "$AFD_RULES_OK" -eq 0 ]; then
        ok "File deletion audit rules already correctly configured"
        return
    fi

    if [ -z "$AFD_UID_MIN" ]; then
        crit "Unable to determine UID_MIN, cannot apply"
        return
    fi

    info "Configuring file deletion audit rules"
    mkdir -p "$AUDIT_RULES_DIR"

    # Remove any existing delete rules to avoid duplicates
    if [ -f "$AUDIT_RULES_FILE" ]; then
        sed -i '/\-k delete/d' "$AUDIT_RULES_FILE"
    fi

    # Create file with header if it doesn't exist
    if [ ! -f "$AUDIT_RULES_FILE" ]; then
        echo "## File deletion events" >"$AUDIT_RULES_FILE"
    fi

    # Add the rules
    {
        echo "-a always,exit -F arch=b64 -S rename,unlink,unlinkat,renameat -F auid>=${AFD_UID_MIN} -F auid!=unset -k delete"
        echo "-a always,exit -F arch=b32 -S rename,unlink,unlinkat,renameat -F auid>=${AFD_UID_MIN} -F auid!=unset -k delete"
    } >>"$AUDIT_RULES_FILE"

    # Load the rules
    info "Loading audit rules"
    augenrules --load
    ok "File deletion audit rules configured and loaded"
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
