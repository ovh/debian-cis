#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password history remember is configured for root (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure pam_pwhistory includes enforce_for_root option."

PAM_CONFIGS_DIR="/usr/share/pam-configs"
PAM_FILE="/etc/pam.d/common-password"
PAM_PATTERN="pam_pwhistory\.so.*enforce_for_root"

# Global state
PAM_ENFORCE_ROOT_PRESENT=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    # Check if enforce_for_root is present in pam-configs
    local pam_configs_ok=0
    if grep -r "$PAM_PATTERN" "$PAM_CONFIGS_DIR" >/dev/null 2>&1; then
        ok "enforce_for_root option is present in pam-configs"
    else
        crit "enforce_for_root option is not present in pam-configs"
        pam_configs_ok=1
    fi

    # Also check in actual PAM file
    local pam_file_ok=0
    if grep "$PAM_PATTERN" "$PAM_FILE" >/dev/null 2>&1; then
        ok "enforce_for_root option is active in $PAM_FILE"
    else
        crit "enforce_for_root option is not active in $PAM_FILE"
        pam_file_ok=1
    fi

    # Set global state: fail if ANY check failed
    if [ "$pam_configs_ok" -ne 0 ] || [ "$pam_file_ok" -ne 0 ]; then
        PAM_ENFORCE_ROOT_PRESENT=1
    else
        PAM_ENFORCE_ROOT_PRESENT=0
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PAM_ENFORCE_ROOT_PRESENT" -ne 0 ]; then
        info "Adding enforce_for_root option to pwhistory PAM configuration"

        # Find pwhistory pam-config files
        local config_files
        config_files=$(grep -l "pam_pwhistory\.so" "$PAM_CONFIGS_DIR"/* 2>/dev/null || true)

        if [ -z "$config_files" ]; then
            crit "No pam_pwhistory configuration found in $PAM_CONFIGS_DIR"
            return
        fi

        # Add enforce_for_root to each pwhistory line, removing duplicates first
        for config_file in $config_files; do
            backup_file "$config_file"
            info "Processing $config_file"

            # First remove any existing enforce_for_root on pam_pwhistory.so lines to prevent duplicates
            sed -i '/pam_pwhistory\.so/ s/[[:space:]]*enforce_for_root//g' "$config_file"
            # Then add it once at the end of each pam_pwhistory.so line
            sed -i '/pam_pwhistory\.so/ s/$/ enforce_for_root/' "$config_file"
        done

        # Re-run pam-auth-update to apply changes
        info "Running pam-auth-update to apply changes"
        DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable pwhistory || true
    else
        ok "enforce_for_root option already configured"
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
