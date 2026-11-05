#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure successful and unsuccessful attempts to use the usermod command are recorded (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure successful and unsuccessful attempts to use the usermod command are recorded."

AUM_RULES_FILE='/etc/audit/rules.d/50-usermod.rules'
AUM_CMD_PATH='/usr/sbin/usermod'

# Global state
AUM_RULES_OK=1
AUM_UID_MIN=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    local l_result

    AUM_UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    if [ -z "$AUM_UID_MIN" ]; then
        crit "UID_MIN is not set in /etc/login.defs"
        return
    fi

    get_effective_audit_rules
    if [ "$FNRET" != 0 ]; then
        crit "Unable to read $AUDIT_RULES_EFFECTIVE_FILE"
        return
    fi

    # "-a always,exit" rule on the command path, with perm=x, auid>=UID_MIN, auid!=unset and a key
    l_result=$(awk -v path="$AUM_CMD_PATH" -v uid_min="$AUM_UID_MIN" '
        $1 == "-a" && ($2 == "always,exit" || $2 == "exit,always") {
            p = 0; perm = 0; auid_min = 0; auid_set = 0; key = 0
            for (i = 3; i < NF; i++) {
                if ($i == "-F") {
                    f = $(i + 1)
                    if (f == "path=" path) p = 1
                    else if (f == "perm=x") perm = 1
                    else if (f == "auid>=" uid_min) auid_min = 1
                    else if (f ~ /^auid!=(unset|-1|4294967295)$/) auid_set = 1
                    else if (f ~ /^key=[!-~]+$/) key = 1
                } else if ($i == "-k") {
                    key = 1
                }
            }
            if (p && perm && auid_min && auid_set && key) print
        }' <<<"$AUDIT_RULES_CONTENT")

    if [ -n "$l_result" ]; then
        ok "usermod command auditing is properly configured in $AUDIT_RULES_EFFECTIVE_FILE"
        AUM_RULES_OK=0
    else
        crit "usermod command auditing is not configured in $AUDIT_RULES_EFFECTIVE_FILE"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$AUM_RULES_OK" = 0 ]; then
        ok "usermod command auditing is already configured"
        return
    fi

    if [ -z "$AUM_UID_MIN" ]; then
        crit "UID_MIN is not set, cannot apply"
        return
    fi

    info "Adding usermod audit rule to $AUM_RULES_FILE"
    mkdir -p "$(dirname "$AUM_RULES_FILE")"
    if [ -f "$AUM_RULES_FILE" ]; then
        backup_file "$AUM_RULES_FILE"
        # remove previous rules for this command to avoid duplicates
        sed -i -E "\\#path=${AUM_CMD_PATH}([[:space:]]|$)#d" "$AUM_RULES_FILE"
    else
        echo "# Audit rules for usermod command - CIS Benchmark" >"$AUM_RULES_FILE"
        chmod 0640 "$AUM_RULES_FILE"
    fi
    echo "-a always,exit -F path=${AUM_CMD_PATH} -F perm=x -F auid>=${AUM_UID_MIN} -F auid!=unset -k usermod" >>"$AUM_RULES_FILE"

    load_audit_rules
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
