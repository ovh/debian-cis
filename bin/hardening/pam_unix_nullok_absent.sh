#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure pam_unix does not include nullok (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
DESCRIPTION="Ensure pam_unix does not include nullok"

# The nullok argument overrides the default action of pam_unix.so to not permit the user access to a service if their official password is blank.

# This function will be called if the script status is on enabled / audit mode
audit() {
    PAM_INVALID_FILES=""

    if grep "pam_unix\.so" /etc/pam.d/common-{password,auth,account,session,session-noninteractive} >/dev/null; then
        PAM_INVALID_FILES=$(grep -HP -- '^\h*^\h*[^#\n\r]+\h+pam_unix\.so\b' /etc/pam.d/common-{password,auth,account,session,session-noninteractive} | awk -F ':' '/nullok/ {print $1}')
    fi

    for file in $PAM_INVALID_FILES; do
        crit "$file contains nullok"
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ -n "$PAM_INVALID_FILES" ]; then
        info "editing pam-config files to remove nullok"
        sed -i 's/nullok//g' /usr/share/pam-configs/*

        # if custom files are being used, the corresponding files in /etc/pam.d/ would need
        # to be edited directly, and the pam-auth-update --enable <EDITED_PROFILE_NAME>
        # command skipped
        # -> so we edit directly also the pam.d files
        for file in $PAM_INVALID_FILES; do
            info "editing $file to remove nullok"
            sed -i 's/nullok//g' "$file"
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
