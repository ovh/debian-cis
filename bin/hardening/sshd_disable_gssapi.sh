#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure GSSAPIAuthentication is disabled (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure GSSAPIAuthentication is disabled in SSH."

PACKAGE='openssh-server'
FILE='/etc/ssh/sshd_config'
OPTION='GSSAPIAuthentication'
VALUE='no'

# Global state
SSH_INSTALLED=1
OPTION_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    SSH_INSTALLED=1
    OPTION_OK=1

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed"
        SSH_INSTALLED=0
        return
    fi
    ok "$PACKAGE is installed"

    PATTERN="^${OPTION}[[:space:]]*${VALUE}"
    does_pattern_exist_in_file_nocase "$FILE" "$PATTERN"
    if [ "$FNRET" = 0 ]; then
        ok "$OPTION is set to $VALUE in $FILE"
    else
        crit "$OPTION is not properly set to $VALUE in $FILE"
        OPTION_OK=0
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SSH_INSTALLED" -eq 0 ]; then
        ok "$PACKAGE is not installed, nothing to apply"
        return
    fi

    if [ "$OPTION_OK" -eq 0 ]; then
        info "Setting $OPTION to $VALUE in $FILE"
        backup_file "$FILE"

        # Check if option already exists with wrong value
        does_pattern_exist_in_file_nocase "$FILE" "^${OPTION}"
        if [ "$FNRET" = 0 ]; then
            # Option exists, replace it
            info "Replacing existing $OPTION directive"
            # Delete all existing occurrences to avoid duplicates
            delete_line_in_file "$FILE" "^${OPTION}"
        fi

        # Add the correct option
        add_end_of_file "$FILE" "$OPTION $VALUE"

        # Test sshd config
        if sshd -t 2>/dev/null; then
            ok "SSH configuration is valid"
            info "Reloading SSH service"
            systemctl reload sshd || systemctl reload ssh || /etc/init.d/ssh reload
        else
            crit "SSH configuration test failed, not reloading"
        fi
    else
        ok "$OPTION already correctly configured"
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
