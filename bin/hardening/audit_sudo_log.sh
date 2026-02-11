#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure sudo log file is audited (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Ensure audit rules for sudo log file are configured."

AUDIT_RULES_FILE='/etc/audit/rules.d/50-sudo.rules'
AUDIT_RULES_DIR='/etc/audit/rules.d'

# Global state
ASL_RULES_OK=1
ASL_SUDO_LOG_FILE=""

# This function will be called if the script status is on enabled / audit mode
audit() {

    # Find sudo log file from sudoers configuration
    ASL_SUDO_LOG_FILE=$($SUDO_CMD grep -r logfile /etc/sudoers* 2>/dev/null | sed -e 's/.*logfile=//;s/,.*//;s/"//g' | head -n1)

    if [ -z "$ASL_SUDO_LOG_FILE" ]; then
        warn "No sudo logfile configured in sudoers, skipping audit rule check"
        return
    fi

    # Escape path for grep
    local l_escaped_path
    l_escaped_path="${ASL_SUDO_LOG_FILE//\//\\/}"

    # Check on disk configuration
    local l_ondisk_result
    l_ondisk_result=$(awk "/^ *-w/ &&/${l_escaped_path}/ &&/ -p *wa/ &&(/ key= *[!-~]* *$/||/ -k *[!-~]* *$/)" "$AUDIT_RULES_DIR"/*.rules 2>/dev/null || true)

    # Check running configuration
    local l_running_result
    l_running_result=$($SUDO_CMD auditctl -l 2>/dev/null | awk "/^ *-w/ &&/${l_escaped_path}/ &&/ -p *wa/ &&(/ key= *[!-~]* *$/||/ -k *[!-~]* *$/)" || true)

    if [ -n "$l_ondisk_result" ] && [ -n "$l_running_result" ]; then
        ok "Sudo log file $ASL_SUDO_LOG_FILE is correctly audited on disk and running"
        ASL_RULES_OK=0
    else
        if [ -z "$l_ondisk_result" ]; then
            crit "Sudo log file $ASL_SUDO_LOG_FILE audit rule not found in on-disk configuration"
        fi
        if [ -z "$l_running_result" ]; then
            crit "Sudo log file $ASL_SUDO_LOG_FILE audit rule not found in running configuration"
        fi
        ASL_RULES_OK=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$(id -u)" -ne 0 ]; then
        crit "This function must be run as root (current user: $(whoami))"
        return 1
    fi

    if [ -z "$ASL_SUDO_LOG_FILE" ]; then
        warn "No sudo logfile configured in sudoers, cannot create audit rule"
        return
    fi

    if [ "$ASL_RULES_OK" -eq 0 ]; then
        ok "Sudo log audit rules already correctly configured"
        return
    fi

    info "Configuring sudo log audit rules for $ASL_SUDO_LOG_FILE"
    mkdir -p "$AUDIT_RULES_DIR"

    # Remove any existing sudo_log_file rules to avoid duplicates
    if [ -f "$AUDIT_RULES_FILE" ]; then
        sed -i '/\-k sudo_log_file/d' "$AUDIT_RULES_FILE"
    fi

    # Create file with header if it doesn't exist
    if [ ! -f "$AUDIT_RULES_FILE" ]; then
        echo "## Sudo log file" >"$AUDIT_RULES_FILE"
    fi

    # Add the rule
    echo "-w $ASL_SUDO_LOG_FILE -p wa -k sudo_log_file" >>"$AUDIT_RULES_FILE"

    # Load the rules
    info "Loading audit rules"
    augenrules --load
    ok "Sudo log audit rules configured and loaded"
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
