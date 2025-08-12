#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password quality checking is enforced (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password quality checking is enforced"

# This function will be called if the script status is on enabled / audit mode
audit() {
    QUALITY_VALID=0
    DISABLED_IN_PAM=1

    for file in /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf; do
        if grep -Psi -- '^\h*enforcing\h*=\h*0\b' "$file" >/dev/null 2>&1; then
            QUALITY_VALID=1
            break
        fi
    done

    if grep -PHsi -- '^\h*password\h+[^#\n\r]+\h+pam_pwquality\.so\h+([^#\n\r]+\h+)?enforcing=0\b' /etc/pam.d/common-password >/dev/null; then
        DISABLED_IN_PAM=0
        QUALITY_VALID=1
    fi

    if [ "$QUALITY_VALID" -eq 0 ]; then
        ok "password quality is enforced"
    else
        crit "password quality is not enforced"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$QUALITY_VALID" -ne 0 ]; then
        for file in /usr/share/pam-configs/* /etc/security/pwquality.conf; do
            if grep -Psi -- '^\h*enforcing\h*=\h*0\b' "$file" >/dev/null 2>&1; then
                info "Commenting 'enforcing=0' in $file"
                sed -ri 's/^\s*enforcing\s*=\s*0/# &/' "$file"
            fi
        done
    fi

    if [ "$DISABLED_IN_PAM" -ne 1 ]; then
        info "Removing 'enforcing=0' in /etc/pam.d/common-password"
        sed -E -i 's/enforcing[[:space:]]?=[[:space:]]?0//g' /etc/pam.d/common-password
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
