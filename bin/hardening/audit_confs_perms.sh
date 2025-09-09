#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure audit configuration files mode is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="the audit configuration files have mode 640 or more restrictive"

AUDITD_CONF_DIR="/etc/audit"

# This function will be called if the script status is on enabled / audit mode
audit() {
    AUDIT_INVALID_PERM_FILES=""

    does_file_exist "$AUDITD_CONF_DIR"
    if [ "$FNRET" -eq 0 ]; then

        AUDIT_INVALID_PERM_FILES=$($SUDO_CMD find "$AUDITD_CONF_DIR" -type f \( -name '*.conf' -o -name '*.rules' \) -perm /0137)

        if [ -n "$AUDIT_INVALID_PERM_FILES" ]; then
            crit "Some files have invalid permissions"
            for file in $AUDIT_INVALID_PERM_FILES; do
                info "$file"
            done
        fi

    else
        info "$AUDITD_CONF_DIR does not exist"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    for file in $AUDIT_INVALID_PERM_FILES; do
        info "Set perm 640 to $file"
        chmod 0640 "$file"
    done
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
