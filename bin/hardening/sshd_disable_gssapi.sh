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

# Global state (0=success, 1=failure)
SSHD_GSSAPI_PKG_INSTALLED=1
SSHD_GSSAPI_OPTION_OK=1

# Check function to populate state
sshd_gssapi_check() {
    SSHD_GSSAPI_PKG_INSTALLED=1
    SSHD_GSSAPI_OPTION_OK=1

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        # Package not installed (0=installed/success, 1=not installed/failure)
        SSHD_GSSAPI_PKG_INSTALLED=1
        return
    fi
    SSHD_GSSAPI_PKG_INSTALLED=0

    PATTERN_CORRECT="^${OPTION}[[:space:]]*${VALUE}"
    PATTERN_ANY="^${OPTION}[[:space:]]"

    local found_correct=0

    # Check main config file
    does_pattern_exist_in_file_nocase "$FILE" "$PATTERN_ANY" && {
        does_pattern_exist_in_file_nocase "$FILE" "$PATTERN_CORRECT"
        [ "$FNRET" = 0 ] || return # Wrong value found (1=failure)
        found_correct=1
    }

    # Check .conf files in Include directories
    if [ -f "$FILE" ]; then
        # shellcheck disable=SC2013
        for include_dir in $(grep -E "^Include" "$FILE" | awk '{print $2}'); do
            # Expand the path if it contains wildcards
            for conf_file in ${include_dir}; do
                if [ -f "$conf_file" ]; then
                    does_pattern_exist_in_file_nocase "$conf_file" "$PATTERN_ANY" && {
                        does_pattern_exist_in_file_nocase "$conf_file" "$PATTERN_CORRECT"
                        [ "$FNRET" = 0 ] || return # Wrong value found (1=failure)
                        found_correct=1
                    }
                elif [ -d "$conf_file" ]; then
                    # If it's a directory, check all .conf files in it
                    for file in "$conf_file"/*.conf; do
                        if [ -f "$file" ]; then
                            does_pattern_exist_in_file_nocase "$file" "$PATTERN_ANY" && {
                                does_pattern_exist_in_file_nocase "$file" "$PATTERN_CORRECT"
                                [ "$FNRET" = 0 ] || return # Wrong value found (1=failure)
                                found_correct=1
                            }
                        fi
                    done
                fi
            done
        done
    fi

    # All files checked: set to success only if correct value found at least once
    [ "$found_correct" = 1 ] && SSHD_GSSAPI_OPTION_OK=0
    # else: remains at 1 (failure)
}

# This function will be called if the script status is on enabled / audit mode
audit() {
    sshd_gssapi_check

    if [ "$SSHD_GSSAPI_PKG_INSTALLED" -ne 0 ]; then
        ok "$PACKAGE is not installed"
        return
    fi
    ok "$PACKAGE is installed"

    if [ "$SSHD_GSSAPI_OPTION_OK" -eq 0 ]; then
        ok "$OPTION is set to $VALUE in $FILE"
    else
        crit "$OPTION is not properly set to $VALUE in $FILE"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SSHD_GSSAPI_PKG_INSTALLED" -ne 0 ]; then
        ok "$PACKAGE is not installed, nothing to apply"
        return
    fi

    if [ "$SSHD_GSSAPI_OPTION_OK" -ne 0 ]; then
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
            is_systemctl_running
            if [ "$FNRET" = 0 ]; then
                systemctl reload sshd || systemctl reload ssh || /etc/init.d/ssh reload
            else
                /etc/init.d/ssh reload
            fi
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
