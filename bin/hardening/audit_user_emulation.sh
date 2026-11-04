#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure actions as another user are always logged (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure actions as another user are always logged."

AUE_RULES_FILE='/etc/audit/rules.d/50-user_emulation.rules'
AUE_RULES_KEY='user_emulation'

# Global state
AUE_RULES_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    local l_archs

    get_effective_audit_rules
    if [ "$FNRET" != 0 ]; then
        crit "Unable to read $AUDIT_RULES_EFFECTIVE_FILE"
        return
    fi

    # print each architecture (b32/b64) audited by an "-a always,exit" rule on execve,
    # with euid!=uid, auid!=unset and a key
    l_archs=$(awk '
        $1 == "-a" && ($2 == "always,exit" || $2 == "exit,always") {
            arch = ""; auid_set = 0; euid = 0; execve = 0; key = 0
            for (i = 3; i < NF; i++) {
                if ($i == "-F") {
                    f = $(i + 1)
                    if (f ~ /^arch=b(32|64)$/) arch = substr(f, 6)
                    else if (f ~ /^auid!=(unset|-1|4294967295)$/) auid_set = 1
                    else if (f ~ /^key=[!-~]+$/) key = 1
                } else if ($i == "-C") {
                    if ($(i + 1) == "euid!=uid" || $(i + 1) == "uid!=euid") euid = 1
                } else if ($i == "-k") {
                    key = 1
                } else if ($i == "-S") {
                    n = split($(i + 1), s, ",")
                    for (j = 1; j <= n; j++) if (s[j] == "execve") execve = 1
                }
            }
            if (arch != "" && auid_set && euid && execve && key) found[arch] = 1
        }
        END {
            if ("b32" in found) print "b32"
            if ("b64" in found) print "b64"
        }' <<<"$AUDIT_RULES_CONTENT" | xargs)

    if [ "$l_archs" = "b32 b64" ]; then
        ok "User emulation auditing is properly configured for both architectures in $AUDIT_RULES_EFFECTIVE_FILE"
        AUE_RULES_OK=0
    else
        crit "User emulation auditing is not properly configured in $AUDIT_RULES_EFFECTIVE_FILE (configured arch: ${l_archs:-none})"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$AUE_RULES_OK" = 0 ]; then
        ok "User emulation auditing is already configured"
        return
    fi

    info "Adding user emulation audit rules to $AUE_RULES_FILE"
    mkdir -p "$(dirname "$AUE_RULES_FILE")"
    if [ -f "$AUE_RULES_FILE" ]; then
        backup_file "$AUE_RULES_FILE"
        # remove previous rules with the same key to avoid duplicates
        sed -i -E "/(-k[[:space:]]+|key=)${AUE_RULES_KEY}([[:space:]]|$)/d" "$AUE_RULES_FILE"
    else
        echo "# Audit rules for user emulation - CIS Benchmark" >"$AUE_RULES_FILE"
        chmod 0640 "$AUE_RULES_FILE"
    fi
    {
        echo "-a always,exit -F arch=b64 -C euid!=uid -F auid!=unset -S execve -k ${AUE_RULES_KEY}"
        echo "-a always,exit -F arch=b32 -C euid!=uid -F auid!=unset -S execve -k ${AUE_RULES_KEY}"
    } >>"$AUE_RULES_FILE"

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
