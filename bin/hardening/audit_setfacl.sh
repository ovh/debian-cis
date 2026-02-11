#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure use of setfacl command is audited (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure audit rules for setfacl command are configured."

AUDIT_RULES_FILE='/etc/audit/rules.d/50-perm_chng.rules'
AUDIT_RULES_DIR='/etc/audit/rules.d'

# Global state
ASF_RULES_OK=1
ASF_UID_MIN=""

# This function will be called if the script status is on enabled / audit mode
audit() {

    # Get UID_MIN
    ASF_UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    if [ -z "$ASF_UID_MIN" ]; then
        crit "Unable to determine UID_MIN from /etc/login.defs"
        return
    fi

    # Check on disk configuration
    local l_ondisk_result
    l_ondisk_result=$(awk "/^ *-a *always,exit/ &&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) &&/ -F *auid>=${ASF_UID_MIN}/ &&/ -F *perm=x/ &&/ -F *path=\/usr\/bin\/setfacl/ &&(/ key= *[!-~]* *$/||/ -k *[!-~]* *$/)" "$AUDIT_RULES_DIR"/*.rules 2>/dev/null || true)

    # Check running configuration
    local l_running_result
    l_running_result=$($SUDO_CMD auditctl -l 2>/dev/null | awk "/^ *-a *always,exit/ &&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) &&/ -F *auid>=${ASF_UID_MIN}/ &&/ -F *perm=x/ &&/ -F *path=\/usr\/bin\/setfacl/ &&(/ key= *[!-~]* *$/||/ -k *[!-~]* *$/)" || true)

    if [ -n "$l_ondisk_result" ] && [ -n "$l_running_result" ]; then
        ok "setfacl audit rules are correctly configured on disk and running"
        ASF_RULES_OK=0
    else
        if [ -z "$l_ondisk_result" ]; then
            crit "setfacl audit rule not found in on-disk configuration"
        fi
        if [ -z "$l_running_result" ]; then
            crit "setfacl audit rule not found in running configuration"
        fi
        ASF_RULES_OK=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$(id -u)" -ne 0 ]; then
        crit "This function must be run as root (current user: $(whoami))"
        return 1
    fi

    if [ "$ASF_RULES_OK" -eq 0 ]; then
        ok "setfacl audit rules already correctly configured"
        return
    fi

    if [ -z "$ASF_UID_MIN" ]; then
        crit "Unable to determine UID_MIN, cannot apply"
        return
    fi

    info "Configuring setfacl audit rules"
    mkdir -p "$AUDIT_RULES_DIR"

    # Remove any existing setfacl rules to avoid duplicates
    if [ -f "$AUDIT_RULES_FILE" ]; then
        sed -i '/path=\/usr\/bin\/setfacl/d' "$AUDIT_RULES_FILE"
    fi

    # Create file with header if it doesn't exist
    if [ ! -f "$AUDIT_RULES_FILE" ]; then
        echo "## Permission modification" >"$AUDIT_RULES_FILE"
    fi

    # Add the rule
    echo "-a always,exit -F path=/usr/bin/setfacl -F perm=x -F auid>=${ASF_UID_MIN} -F auid!=unset -k perm_chng" >>"$AUDIT_RULES_FILE"

    # Load the rules
    info "Loading audit rules"
    augenrules --load
    ok "setfacl audit rules configured and loaded"
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
