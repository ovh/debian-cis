#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure pam_pwhistory module is enabled (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure pam_pwhistory module is enabled "

PAM_FILE="/etc/pam.d/common-password"
PAM_PATTERN="^[^#].*pam_pwhistory.so"

# This function will be called if the script status is on enabled / audit mode
audit() {
    PAM_VALID=1

    if grep "$PAM_PATTERN" "$PAM_FILE" >/dev/null 2>&1; then
        ok "pam_pwhistory is enabled"
        PAM_VALID=0
    else
        crit "pam_pwhistory is not enabled"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PAM_VALID" -ne 0 ]; then
        # check if already present in an pam-auth-update profile
        # if not
        # - add in a profile
        # then in all cases : pam-auth-update --enable {PROFILE_NAME}
        if ! grep "$PAM_PATTERN" /usr/share/pam-configs/*; then
            pam_update_profile=pwhistory
            arr=('Name: pwhistory password history checking' 'Default: yes' 'Priority: 1024' 'Password-Type: Primary' 'Password:' '   requisite pam_pwhistory.so remember=24 enforce_for_root try_first_pass use_authtok')
            printf '%s\n' "${arr[@]}" >/usr/share/pam-configs/"$pam_update_profile"
        else
            pam_update_profile="$(grep -l "$PAM_PATTERN" /usr/share/pam-configs/* | head -n1)"
        fi
        info "Applying 'pam-auth-update' to enable pw_history.so"
        DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable "$pam_update_profile"
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
