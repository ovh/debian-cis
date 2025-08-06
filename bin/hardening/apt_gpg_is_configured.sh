#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure GPG keys are configured (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure GPG keys are configured"
APT_KEY_PATH="/etc/apt/trusted.gpg.d"
APT_KEY_FILE="/etc/apt/trusted.gpg"
# from "man apt-secure"
SOURCES_UNSECURE_OPTION='allow-insecure=yes'
APT_UNSECURE_OPTION='Acquire::AllowInsecureRepositories=true'

# This function will be called if the script status is on enabled / audit mode
audit() {

    key_files=0
    info "Verifying that apt keys are present"
    # apt-key list requires that gnupg2 is installed
    # we are not going to install it for the sake of a test, so we only check the presence of key files
    is_file_empty "$APT_KEY_FILE"
    if [ "$FNRET" -eq 1 ]; then
        info "$APT_KEY_FILE present and not empty"
        key_files=$((key_files + 1))
    fi

    does_file_exist "$APT_KEY_PATH"
    if [ "$FNRET" -ne 0 ]; then
        info "$APT_KEY_PATH is missing"
    else
        asc_files=$(find "$APT_KEY_PATH" -name '*.asc' | wc -l)
        key_files=$((key_files + asc_files))

        gpg_files=$(find "$APT_KEY_PATH" -name '*.gpg' | wc -l)
        key_files=$((key_files + gpg_files))

        if [ "$asc_files" -eq 0 ] && [ "$gpg_files" -eq 0 ]; then
            info "No key found in $APT_KEY_PATH"
        fi
    fi

    if [ "$key_files" -eq 0 ]; then
        crit "No GPG file found"
    else
        # we do not test the GPG keys validity, but we ensure we don't bypass them
        info "Ensure an unsecure option is not set in some sources list"
        unsecure_sources=$(find /etc/apt/ -name '*.list' -exec grep -l "$SOURCES_UNSECURE_OPTION" {} \;)
        if [ -n "$unsecure_sources" ]; then
            crit "Some source files use $SOURCES_UNSECURE_OPTION : $unsecure_sources"
        fi

        info "Ensure an unsecure option is not set in some apt configuration"
        unsecure_option=$(grep -R "$APT_UNSECURE_OPTION" /etc/apt | wc -l)
        if [ "$unsecure_option" -gt 0 ]; then
            crit "$APT_UNSECURE_OPTION is set in apt configuration"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    audit
    if [ "$FNRET" -gt 0 ]; then
        crit "Your configuraiton does not match the recommendation. Please fix it manually"
    else
        info "Nothing to apply"
    fi
}

# This function will check config parameters required
check_config() {
    # No parameter for this script
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
