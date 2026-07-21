#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure only authorized groups are assigned ownership of audit log files (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure 'root' or 'adm' groups are assigned ownership of audit log files"
AUDITD_CONF_FILE="/etc/audit/auditd.conf"
AUDIT_LOG_GROUP=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    AUDIT_LOG_GROUP_VALID=0
    AUDIT_INVALID_LOGS=""

    does_file_exist "$AUDITD_CONF_FILE"
    if [ "$FNRET" -eq 0 ]; then
        local log_file
        log_file=$($SUDO_CMD grep -E "^\s*log_file" "$AUDITD_CONF_FILE" | awk -F '=' '{print $2}' | xargs)
        log_group=$($SUDO_CMD grep -E "^\s*log_group" "$AUDITD_CONF_FILE" | awk -F '=' '{print $2}' | xargs)
        # look for all files in the directory
        AUDIT_INVALID_LOGS=$(find "$(dirname "$log_file")" -type f ! -group "$AUDIT_LOG_GROUP" -a ! -group root -exec stat -Lc "%n %G" {} +)

        if [ -n "$AUDIT_INVALID_LOGS" ]; then
            crit "Some audit logs are not owned by group $AUDIT_LOG_GROUP nor root"
            for file in $AUDIT_INVALID_LOGS; do
                info "$file"
            done
        fi

        if [[ "$log_group" != "$AUDIT_LOG_GROUP" ]]; then
            crit "'log_group' is '$log_group' instead of '$AUDIT_LOG_GROUP' in $AUDITD_CONF_FILE"
            AUDIT_LOG_GROUP_VALID=1
        fi

    else
        info "$AUDITD_CONF_FILE does not exist"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$AUDIT_LOG_GROUP_VALID" -eq 1 ]; then
        info "changing log_group to $AUDIT_LOG_GROUP in $AUDITD_CONF_FILE"
        sed -Ei "/\s*log_group/s/=.*$/=$AUDIT_LOG_GROUP/" "$AUDITD_CONF_FILE"
    fi

    if [ -n "$AUDIT_INVALID_LOGS" ]; then
        for file in $AUDIT_INVALID_LOGS; do
            file_path=$(awk '{print $1}' <<<"$file")
            info "Change group to '$AUDIT_LOG_GROUP' for '$file_path'"
            chgrp "$AUDIT_LOG_GROUP" "$file_path"
        done
    fi
}

# This function will check config parameters required
check_config() {
    :
}

create_config() {
    cat <<EOF
# shellcheck disable=2034
status=audit
# put here the group name that maybe allowed to own audit log files
# this is the one found under the "log_group" directive in /etc/audit/auditd.conf
# the 'root' group is allowed in addition to this one
AUDIT_LOG_GROUP='adm'
EOF
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
