#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure only authorized users own audit log files (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="audit log files should be owned by the correct user"

AUDITD_CONF_FILE="/etc/audit/auditd.conf"
AUDIT_LOG_USER=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    AUDIT_INVALID_LOGS=""

    does_file_exist "$AUDITD_CONF_FILE"
    if [ "$FNRET" -eq 0 ]; then
        local log_file
        log_file=$($SUDO_CMD grep -E "^\s*log_file" "$AUDITD_CONF_FILE" | awk -F '=' '{print $2}' | xargs)
        # look for all files in the directory
        AUDIT_INVALID_LOGS=$(find "$(dirname "$log_file")" -type f ! -user "$AUDIT_LOG_USER" -exec stat -Lc "%n %U" {} +)

        if [ -n "$AUDIT_INVALID_LOGS" ]; then
            crit "Some audit logs are not owned by $AUDIT_LOG_USER"
            for file in $AUDIT_INVALID_LOGS; do
                info "$file"
            done
        fi
    else
        info "$AUDITD_CONF_FILE does not exist"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ -n "$AUDIT_INVALID_LOGS" ]; then

        for file in $AUDIT_INVALID_LOGS; do
            file_path=$(awk '{print $1}' <<<"$file")
            info "Change owner to '$AUDIT_LOG_USER' for '$file_path'"
            chown "$AUDIT_LOG_USER" "$file_path"
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
AUDIT_LOG_USER='root'
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
