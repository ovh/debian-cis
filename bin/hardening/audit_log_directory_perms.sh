#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure the audit log directory mode is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure the audit log directory mode is configured"

AUDITD_CONF_FILE="/etc/audit/auditd.conf"
AUDIT_LOG_DIR_EXPECTED_PERM=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    AUDIT_LOG_DIR_PERMS=0

    does_file_exist "$AUDITD_CONF_FILE"
    if [ "$FNRET" -eq 0 ]; then

        AUDIT_LOG_DIRECTORY="$(dirname "$($SUDO_CMD grep -E "^\s*log_file" "$AUDITD_CONF_FILE" | awk -F '=' '{print $2}' | xargs)")"
        local log_dir_perms
        log_dir_perms=$(stat -Lc %a "$AUDIT_LOG_DIRECTORY")

        # 0750 will be output as 750 by stat
        # we add the missing 0 ourselves for easier comparison
        if [ "$(echo -n "$log_dir_perms" | wc -m)" -lt 4 ]; then
            log_dir_perms="0$log_dir_perms"
        fi

        if [ "$log_dir_perms" != "$AUDIT_LOG_DIR_EXPECTED_PERM" ]; then
            crit "audit log directory '$AUDIT_LOG_DIRECTORY' permissions are '$log_dir_perms' instead of '$AUDIT_LOG_DIR_EXPECTED_PERM'"
            AUDIT_LOG_DIR_PERMS=1
        fi

    else
        info "$AUDITD_CONF_FILE does not exist"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$AUDIT_LOG_DIR_PERMS" -eq 1 ]; then
        info "changing permission to on '$AUDIT_LOG_DIR_EXPECTED_PERM' '$AUDIT_LOG_DIRECTORY'"
        chmod "$AUDIT_LOG_DIR_EXPECTED_PERM" "$AUDIT_LOG_DIRECTORY"
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
# the expected permission for the directory owning the "log_file" directive in /etc/audit/auditd.conf
# default is 0750, but can be less permissive
AUDIT_LOG_DIR_EXPECTED_PERM="0750"
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
