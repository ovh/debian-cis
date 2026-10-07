#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password history remember is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure pam_pwhistory remember is configured to 24 or more"

PWHR_PACKAGE="libpam-modules"
PWHR_PAM_FILE="/etc/pam.d/common-password"
PWHR_PAM_CONFIGS_DIR="/usr/share/pam-configs"
PWHR_MIN_REMEMBER=""
PWHR_PROFILE_NAME="pwhistory"

# Global state (0 = compliant, 1 = non-compliant)
PWHR_COMPLIANT=1
PWHR_PACKAGE_INSTALLED=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    PWHR_PACKAGE_INSTALLED=1

    is_pkg_installed "$PWHR_PACKAGE"
    if [ "$FNRET" != 0 ]; then
        crit "$PWHR_PACKAGE is not installed"
        return
    fi
    ok "$PWHR_PACKAGE is installed"
    PWHR_PACKAGE_INSTALLED=0

    local pwhistory_lines
    pwhistory_lines=$(grep -P -- '^\h*password\h+[^#\n\r]+\h+pam_pwhistory\.so\b' "$PWHR_PAM_FILE" || true)

    if [ -z "$pwhistory_lines" ]; then
        crit "pam_pwhistory line is missing in $PWHR_PAM_FILE"
        return
    fi

    local all_lines_compliant=0
    local line remember_value
    while IFS= read -r line; do
        remember_value=$(sed -nE 's/.*\bremember=([0-9]+)\b.*/\1/p' <<<"$line")
        if [ -z "$remember_value" ]; then
            crit "pam_pwhistory line has no remember value: $line"
            all_lines_compliant=1
            continue
        fi

        if [ "$remember_value" -lt "$PWHR_MIN_REMEMBER" ]; then
            crit "pam_pwhistory remember value $remember_value is lower than $PWHR_MIN_REMEMBER"
            all_lines_compliant=1
            continue
        fi

        ok "pam_pwhistory remember value $remember_value is compliant"
    done <<EOF
$pwhistory_lines
EOF

    if [ "$all_lines_compliant" -eq 0 ]; then
        PWHR_COMPLIANT=0
    else
        PWHR_COMPLIANT=1
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PWHR_PACKAGE_INSTALLED" -ne 0 ]; then
        crit "$PWHR_PACKAGE is absent, installing it"
        apt_install "$PWHR_PACKAGE"
    fi

    if [ "$PWHR_COMPLIANT" -eq 0 ]; then
        ok "pam_pwhistory remember value is already compliant"
        return
    fi

    info "Ensuring pam_pwhistory remember value is at least $PWHR_MIN_REMEMBER in pam-config profiles"

    local profile_files
    profile_files=$(grep -l "pam_pwhistory\.so" "$PWHR_PAM_CONFIGS_DIR"/* 2>/dev/null || true)

    if [ -z "$profile_files" ]; then
        info "No pam_pwhistory profile found, creating $PWHR_PAM_CONFIGS_DIR/$PWHR_PROFILE_NAME"
        {
            echo "Name: pwhistory password history checking"
            echo "Default: yes"
            echo "Priority: 1024"
            echo "Password-Type: Primary"
            echo "Password:"
            echo "   requisite pam_pwhistory.so remember=$PWHR_MIN_REMEMBER enforce_for_root try_first_pass use_authtok"
        } >"$PWHR_PAM_CONFIGS_DIR/$PWHR_PROFILE_NAME"
        DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable "$PWHR_PROFILE_NAME"
        return
    fi

    local profile_file profile_name
    for profile_file in $profile_files; do
        profile_name=$(basename "$profile_file")
        backup_file "$profile_file"

        # Remove existing remember argument to avoid duplicates before setting policy value.
        sed -i '/pam_pwhistory\.so/ s/\<remember=[0-9]\+\>//g' "$profile_file"
        sed -i "/pam_pwhistory\\.so/ s/$/ remember=$PWHR_MIN_REMEMBER/" "$profile_file"

        info "Applying pam profile $profile_name"
        DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable "$profile_name"
    done
}

# This function will create config parameters
create_config() {
    echo "status=audit"
    echo "PWHR_MIN_REMEMBER=24"
}

# This function will check config parameters required
check_config() {
    if [ -z "$PWHR_MIN_REMEMBER" ]; then
        PWHR_MIN_REMEMBER=24
    fi
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
