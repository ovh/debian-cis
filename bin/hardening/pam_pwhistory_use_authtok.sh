#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password history remember includes use_authtok (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure pam_pwhistory includes use_authtok option."

PAM_CONFIGS_DIR="/usr/share/pam-configs"
PAM_FILE="/etc/pam.d/common-password"
PAM_PATTERN="pam_pwhistory\.so.*use_authtok"

# Global state
OPTION_PRESENT=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    OPTION_PRESENT=1

    # Check if use_authtok is present in pam-configs
    if grep -r "$PAM_PATTERN" "$PAM_CONFIGS_DIR" >/dev/null 2>&1; then
        ok "use_authtok option is present in pam-configs"
        OPTION_PRESENT=0
    else
        crit "use_authtok option is not present in pam-configs"
    fi

    # Also check in actual PAM file
    if grep "$PAM_PATTERN" "$PAM_FILE" >/dev/null 2>&1; then
        ok "use_authtok option is active in $PAM_FILE"
    else
        crit "use_authtok option is not active in $PAM_FILE"
        OPTION_PRESENT=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$OPTION_PRESENT" -ne 0 ]; then
        info "Adding use_authtok option to pwhistory PAM configuration"

        # Find pwhistory pam-config files
        local config_files
        config_files=$(grep -l "pam_pwhistory\.so" "$PAM_CONFIGS_DIR"/* 2>/dev/null || true)

        if [ -z "$config_files" ]; then
            crit "No pam_pwhistory configuration found in $PAM_CONFIGS_DIR"
            return
        fi

        # Add use_authtok to each pwhistory line that doesn't have it
        for config_file in $config_files; do
            backup_file "$config_file"
            info "Processing $config_file"

            # Use sed to add use_authtok if not already present on pam_pwhistory.so lines
            sed -i '/pam_pwhistory\.so/ {
                /use_authtok/! s/$/ use_authtok/
            }' "$config_file"
        done

        # Re-run pam-auth-update to apply changes
        info "Running pam-auth-update to apply changes"
        DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable pwhistory || true
    else
        ok "use_authtok option already configured"
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
