#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure audit configuration files belong to group root (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure audit configuration files belong to group root"

AUDITD_CONF_DIR="/etc/audit"
AUDIT_CONF_GROUP=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    AUDIT_INVALID_FILES=""

    does_file_exist "$AUDITD_CONF_DIR"
    if [ "$FNRET" -eq 0 ]; then

        AUDIT_INVALID_FILES=$($SUDO_CMD find "$AUDITD_CONF_DIR" -type f \( -name '*.conf' -o -name '*.rules' \) ! -group "$AUDIT_CONF_GROUP")

        if [ -n "$AUDIT_INVALID_FILES" ]; then
            crit "Some files in $AUDITD_CONF_DIR are not owned by group $AUDIT_CONF_GROUP"
        fi

    else
        info "$AUDITD_CONF_DIR does not exist"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ -n "$AUDIT_INVALID_FILES" ]; then
        for file in $AUDIT_INVALID_FILES; do
            info "changing owner to $AUDIT_CONF_GROUP for $file"
            chgrp "$AUDIT_CONF_GROUP" "$file"
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
# group of the audit configuration files
AUDIT_CONF_GROUP='root'
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
