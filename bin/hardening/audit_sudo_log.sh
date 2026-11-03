#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure events that modify the sudo log file are collected (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure audit rules for sudo log file are configured."

ASL_RULES_FILE='/etc/audit/rules.d/50-sudo.rules'
ASL_RULES_DIR='/etc/audit/rules.d'
ASL_RULES_KEY='sudo_log_file'
# value of the "logfile" option in a "Defaults" entry, "check_logfiles" or comments must not match
ASL_LOGFILE_PATTERN='^\h*Defaults\b[^#]*\blogfile\h*=\h*"?\K[^",\h#]+'
# keep "-w <path>" rules with write and attribute permissions, and a key
# shellcheck disable=2016
ASL_AWK_FILTER='$1 == "-w" && $2 == path {
    perm = ""; key = 0
    for (i = 3; i <= NF; i++) {
        if ($i == "-p" && i < NF) perm = $(i + 1)
        if (($i == "-k" && i < NF) || $i ~ /^key=[!-~]+$/) key = 1
    }
    if (perm ~ /w/ && perm ~ /a/ && key) print
}'

# Global state
ASL_SUDO_LOG_FILE=""
ASL_ONDISK_OK=1
ASL_RUNNING_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    local l_sudoers_files l_rules_files l_ondisk_result l_running_result l_running_rules

    # sudo reads /etc/sudoers then /etc/sudoers.d (lexical order, ignoring files containing "." or ending with "~"),
    # the last logfile setting wins
    l_sudoers_files=$($SUDO_CMD find /etc/sudoers.d -maxdepth 1 -type f ! -name '*.*' ! -name '*~' 2>/dev/null | sort || true)
    # shellcheck disable=2086
    ASL_SUDO_LOG_FILE=$($SUDO_CMD grep -hPo -- "$ASL_LOGFILE_PATTERN" /etc/sudoers $l_sudoers_files 2>/dev/null | tail -n1 || true)

    if [ -z "$ASL_SUDO_LOG_FILE" ]; then
        warn "No sudo logfile configured in sudoers, cannot audit its modifications"
        return
    fi

    l_rules_files=$($SUDO_CMD find "$ASL_RULES_DIR" -maxdepth 1 -type f -name '*.rules' 2>/dev/null || true)
    l_ondisk_result=""
    if [ -n "$l_rules_files" ]; then
        # shellcheck disable=2086
        l_ondisk_result=$($SUDO_CMD cat $l_rules_files 2>/dev/null | awk -v path="$ASL_SUDO_LOG_FILE" "$ASL_AWK_FILTER" || true)
    fi
    if [ -n "$l_ondisk_result" ]; then
        ok "Sudo log file $ASL_SUDO_LOG_FILE audit rule found in on-disk configuration"
        ASL_ONDISK_OK=0
    else
        crit "Sudo log file $ASL_SUDO_LOG_FILE audit rule not found in on-disk configuration"
    fi

    if l_running_rules=$($SUDO_CMD auditctl -l 2>/dev/null); then
        l_running_result=$(awk -v path="$ASL_SUDO_LOG_FILE" "$ASL_AWK_FILTER" <<<"$l_running_rules")
        if [ -n "$l_running_result" ]; then
            ok "Sudo log file $ASL_SUDO_LOG_FILE audit rule found in running configuration"
            ASL_RUNNING_OK=0
        else
            crit "Sudo log file $ASL_SUDO_LOG_FILE audit rule not found in running configuration"
        fi
    else
        crit "Unable to read running audit rules (auditctl -l failed)"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    local l_tmpfile

    if [ -z "$ASL_SUDO_LOG_FILE" ]; then
        warn "No sudo logfile configured in sudoers, configure it first (see logfile_sudo)"
        return
    fi

    if [ "$ASL_ONDISK_OK" = 0 ] && [ "$ASL_RUNNING_OK" = 0 ]; then
        ok "Sudo log audit rules already correctly configured"
        return
    fi

    if [ "$ASL_ONDISK_OK" != 0 ]; then
        info "Configuring sudo log audit rule for $ASL_SUDO_LOG_FILE in $ASL_RULES_FILE"
        mkdir -p "$ASL_RULES_DIR"
        if [ -f "$ASL_RULES_FILE" ]; then
            backup_file "$ASL_RULES_FILE"
            # remove previous rules for this path or key to avoid duplicates
            l_tmpfile=$(mktemp)
            awk -v path="$ASL_SUDO_LOG_FILE" -v key="$ASL_RULES_KEY" \
                '!($1 == "-w" && $2 == path) && $NF != key && $NF != "key=" key' "$ASL_RULES_FILE" >"$l_tmpfile"
            cat "$l_tmpfile" >"$ASL_RULES_FILE"
            rm -f "$l_tmpfile"
        else
            echo "## Sudo log file" >"$ASL_RULES_FILE"
            chmod 0640 "$ASL_RULES_FILE"
        fi
        echo "-w $ASL_SUDO_LOG_FILE -p wa -k $ASL_RULES_KEY" >>"$ASL_RULES_FILE"
    fi

    if ! command -v augenrules >/dev/null 2>&1; then
        warn "augenrules not found, audit rules cannot be loaded"
        return
    fi
    info "Loading audit rules"
    if augenrules --load; then
        ok "Sudo log audit rules configured and loaded"
    else
        warn "augenrules --load failed (audit configuration may be immutable), a reboot may be required"
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
