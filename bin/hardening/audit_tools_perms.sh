#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure audit tools mode is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure audit tools mode is configured"

AUDITD_TOOLS="/sbin/auditctl /sbin/aureport /sbin/ausearch /sbin/autrace /sbin/auditd /sbin/augenrules"

# This function will be called if the script status is on enabled / audit mode
audit() {
    AUDIT_INVALID_FILES=""

    for file in $AUDITD_TOOLS; do

        does_file_exist "$file"
        if [ "$FNRET" -eq 0 ]; then
            if stat -Lc "%n %a" "$file" | grep -Pv -- '^\h*\H+\h+([0-7][0,1,4,5][0,1,4,5])\h*$'; then
                crit "wrong permission $file"
                AUDIT_INVALID_FILES="$AUDIT_INVALID_FILES $file"
            fi

        else
            info "$file missing"
        fi

    done

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ -n "$AUDIT_INVALID_FILES" ]; then
        for file in $AUDIT_INVALID_FILES; do
            info "changing permission to 755 for $file"
            chmod 755 "$file"
        done
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
