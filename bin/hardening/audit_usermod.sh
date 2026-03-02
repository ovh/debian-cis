#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.3.3.18 Ensure successful and unsuccessful attempts to use the usermod command are recorded (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure successful and unsuccessful attempts to use the usermod command are recorded."

AUDIT_RULES_FILE='/etc/audit/rules.d/50-usermod.rules'

# Global state
AUM_RULES_OK=1
AUM_UID_MIN=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    # Get UID_MIN from login.defs
    AUM_UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    if [ -z "$AUM_UID_MIN" ]; then
        crit "UID_MIN is not set in /etc/login.defs"
        return
    fi

    # Check on-disk audit rules
    local on_disk_rules
    on_disk_rules=$(awk "/^ *-a *always,exit/ &&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) &&/ -F *auid>=${AUM_UID_MIN}/ &&/ -F *perm=x/ &&/ -F *path=\/usr\/sbin\/usermod/ &&(/ key= *[!-~]* *$/||/ -k *[!-~]* *$/)" /etc/audit/rules.d/*.rules 2>/dev/null || true)

    # Check running audit rules
    local running_rules
    running_rules=$($SUDO_CMD auditctl -l 2>/dev/null | awk "/^ *-a *always,exit/ &&(/ -F *auid!=unset/||/ -F *auid!=-1/||/ -F *auid!=4294967295/) &&/ -F *auid>=${AUM_UID_MIN}/ &&/ -F *perm=x/ &&/ -F *path=\/usr\/sbin\/usermod/ &&(/ key= *[!-~]* *$/||/ -k *[!-~]* *$/)" || true)

    # Validate results
    if [ -n "$on_disk_rules" ] && [ -n "$running_rules" ]; then
        ok "usermod command auditing is properly configured"
        AUM_RULES_OK=0
    else
        if [ -z "$on_disk_rules" ]; then
            crit "usermod command auditing is not configured in /etc/audit/rules.d/"
        fi
        if [ -z "$running_rules" ]; then
            crit "usermod command auditing is not loaded in running configuration"
        fi
        AUM_RULES_OK=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$AUM_RULES_OK" -eq 0 ]; then
        ok "usermod command auditing is already configured"
        return
    fi

    if [ -z "$AUM_UID_MIN" ]; then
        crit "UID_MIN is not set, cannot apply"
        return
    fi

    # Create audit rules directory if needed
    if [ ! -d /etc/audit/rules.d ]; then
        info "Creating /etc/audit/rules.d directory"
        mkdir -p /etc/audit/rules.d
    fi

    # Remove existing usermod rules to avoid duplicates
    if [ -f "$AUDIT_RULES_FILE" ]; then
        sed -i '/usermod/d' "$AUDIT_RULES_FILE"
    fi

    # Create file with header if it doesn't exist
    if [ ! -f "$AUDIT_RULES_FILE" ]; then
        echo "# Audit rules for usermod command - CIS Benchmark" >"$AUDIT_RULES_FILE"
    fi

    # Add the audit rule
    info "Adding usermod audit rule to $AUDIT_RULES_FILE"
    echo "-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=${AUM_UID_MIN} -F auid!=unset -k usermod" >>"$AUDIT_RULES_FILE"

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
