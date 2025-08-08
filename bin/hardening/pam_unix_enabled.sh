#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure pam_unix module is enabled (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure pam_unix module is enabled"

PAM_FILES="/etc/pam.d/common-auth /etc/pam.d/common-account /etc/pam.d/common-session /etc/pam.d/common-password"
PAM_PATTERN="^[^#].*pam_unix.so"

# This function will be called if the script status is on enabled / audit mode
audit() {
    PAM_VALID=0

    for PAM_FILE in $PAM_FILES; do
        if grep "$PAM_PATTERN" "$PAM_FILE" >/dev/null 2>&1; then
            info "pam_unix found in $PAM_FILE"
        else
            crit "pam_unix not found in $PAM_FILE"
            PAM_VALID=1
        fi
    done

    if [ "$PAM_VALID" -eq 0 ]; then
        ok "pam_unix is enabled"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PAM_VALID" -ne 0 ]; then
        info "Applying 'pam-auth-update' to enable pam_unix.so"
        DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable unix
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
