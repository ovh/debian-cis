#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure file deletion events by users are collected (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure file deletion events are audited"

AFD_RULES_FILE='/etc/audit/rules.d/50-delete.rules'
AFD_RULES_KEY='delete'
# print each architecture (b32/b64) for which unlink, unlinkat, rename and renameat are all audited
# by "-a always,exit" rules filtering on auid>=UID_MIN and auid!=unset, with a key
# shellcheck disable=2016
AFD_AWK_FILTER='$1 == "-a" && ($2 == "always,exit" || $2 == "exit,always") {
    arch = ""; auid_min = 0; auid_set = 0; key = 0
    split("", syscalls)
    for (i = 3; i < NF; i++) {
        if ($i == "-F") {
            f = $(i + 1)
            if (f ~ /^arch=b(32|64)$/) arch = substr(f, 6)
            else if (f == "auid>=" uid_min) auid_min = 1
            else if (f ~ /^auid!=(unset|-1|4294967295)$/) auid_set = 1
            else if (f ~ /^key=[!-~]+$/) key = 1
        } else if ($i == "-k") {
            key = 1
        } else if ($i == "-S") {
            n = split($(i + 1), s, ",")
            for (j = 1; j <= n; j++) syscalls[s[j]] = 1
        }
    }
    if (arch != "" && auid_min && auid_set && key)
        for (sc in syscalls) found[arch "," sc] = 1
}
END {
    split("b32 b64", archs, " ")
    split("unlink unlinkat rename renameat", required, " ")
    for (a = 1; a <= 2; a++) {
        complete = 1
        for (r = 1; r <= 4; r++)
            if (!((archs[a] "," required[r]) in found)) complete = 0
        if (complete) print archs[a]
    }
}'

# Global state
AFD_UID_MIN=""
AFD_RULES_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    local l_archs

    AFD_UID_MIN=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)
    if [ -z "$AFD_UID_MIN" ]; then
        crit "Unable to determine UID_MIN from /etc/login.defs"
        return
    fi

    get_effective_audit_rules
    if [ "$FNRET" != 0 ]; then
        crit "Unable to read $AUDIT_RULES_EFFECTIVE_FILE"
        return
    fi

    l_archs=$(awk -v uid_min="$AFD_UID_MIN" "$AFD_AWK_FILTER" <<<"$AUDIT_RULES_CONTENT" | xargs)
    if [ "$l_archs" = "b32 b64" ]; then
        ok "File deletion audit rules found in $AUDIT_RULES_EFFECTIVE_FILE"
        AFD_RULES_OK=0
    else
        crit "File deletion audit rules not found or incomplete in $AUDIT_RULES_EFFECTIVE_FILE (complete arch: ${l_archs:-none})"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ -z "$AFD_UID_MIN" ]; then
        crit "Unable to determine UID_MIN, cannot apply"
        return
    fi

    if [ "$AFD_RULES_OK" = 0 ]; then
        ok "File deletion audit rules already correctly configured"
        return
    fi

    info "Adding file deletion audit rules to $AFD_RULES_FILE"
    mkdir -p "$(dirname "$AFD_RULES_FILE")"
    if [ -f "$AFD_RULES_FILE" ]; then
        backup_file "$AFD_RULES_FILE"
        # remove previous rules with the same key to avoid duplicates
        sed -i -E "/(-k[[:space:]]+|key=)${AFD_RULES_KEY}([[:space:]]|$)/d" "$AFD_RULES_FILE"
    else
        echo "## File deletion events" >"$AFD_RULES_FILE"
        chmod 0640 "$AFD_RULES_FILE"
    fi
    {
        echo "-a always,exit -F arch=b64 -S rename,unlink,unlinkat,renameat -F auid>=${AFD_UID_MIN} -F auid!=unset -k ${AFD_RULES_KEY}"
        echo "-a always,exit -F arch=b32 -S rename,unlink,unlinkat,renameat -F auid>=${AFD_UID_MIN} -F auid!=unset -k ${AFD_RULES_KEY}"
    } >>"$AFD_RULES_FILE"

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
