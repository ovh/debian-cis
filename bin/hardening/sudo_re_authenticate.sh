#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure re-authentication for privilege escalation is not disabled globally (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure re-authentication for privilege escalation is not disabled globally"
PARAM="!authenticate"

# This function will be called if the script status is on enabled / audit mode
# shellcheck disable=2120
audit() {
    SUDO_PARAM_IS_VALID=0
    local sudo_files

    sudo_files="/etc/sudoers $(find /etc/sudoers.d -type f ! -name README | paste -s)"
    for file in $sudo_files; do
        if $SUDO_CMD grep "$PARAM" "$file"; then
            crit "$PARAM present in $file"
            SUDO_PARAM_IS_VALID=1
        fi
    done

    if [ "$SUDO_PARAM_IS_VALID" -ne 0 ]; then
        ok "'$PARAM' is absent from sudo files"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SUDO_PARAM_IS_VALID" -ne 0 ]; then
        # CIS recommends to manage it in an Automated way.
        # This can easily break the sudoers file, better review it manually
        info "Please review your sudo rules, and remove '!authenticate' from them"
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
