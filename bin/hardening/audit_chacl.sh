#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure use of chacl command is audited (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure audit rules for chacl command are configured."

AC_RULES_FILE='/etc/audit/rules.d/50-perm_chng.rules'
AC_CMD_PATH='/usr/bin/chacl'

# Global state
AC_RULES_OK=1
AC_UID_MIN=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    local l_result

    AC_UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    if [ -z "$AC_UID_MIN" ]; then
        crit "Unable to determine UID_MIN from /etc/login.defs"
        return
    fi

    get_effective_audit_rules
    if [ "$FNRET" != 0 ]; then
        crit "Unable to read $AUDIT_RULES_EFFECTIVE_FILE"
        return
    fi

    # "-a always,exit" rule on the command path, with perm=x, auid>=UID_MIN, auid!=unset and a key
    l_result=$(awk -v path="$AC_CMD_PATH" -v uid_min="$AC_UID_MIN" '
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
        ok "chacl audit rule found in $AUDIT_RULES_EFFECTIVE_FILE"
        AC_RULES_OK=0
    else
        crit "chacl audit rule not found in $AUDIT_RULES_EFFECTIVE_FILE"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$AC_RULES_OK" = 0 ]; then
        ok "chacl audit rule already configured"
        return
    fi

    if [ -z "$AC_UID_MIN" ]; then
        crit "Unable to determine UID_MIN, cannot apply"
        return
    fi

    info "Adding chacl audit rule to $AC_RULES_FILE"
    mkdir -p "$(dirname "$AC_RULES_FILE")"
    if [ -f "$AC_RULES_FILE" ]; then
        backup_file "$AC_RULES_FILE"
        # remove previous rules for this command to avoid duplicates
        sed -i -E "\\#path=${AC_CMD_PATH}([[:space:]]|$)#d" "$AC_RULES_FILE"
    else
        echo "## Permission modification" >"$AC_RULES_FILE"
        chmod 0640 "$AC_RULES_FILE"
    fi
    echo "-a always,exit -F path=${AC_CMD_PATH} -F perm=x -F auid>=${AC_UID_MIN} -F auid!=unset -k perm_chng" >>"$AC_RULES_FILE"

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
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is ${CIS_LIB_DIR} in /etc/default/cis-hardening"
    exit 128
fi
