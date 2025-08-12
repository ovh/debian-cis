#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password quality is enforced for the root user (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password quality is enforced for the root user"

# This function will be called if the script status is on enabled / audit mode
audit() {
    QUALITY_VALID=1

    # order of override from strongest to weakest:
    # - /etc/pam.d/*
    # - /etc/security/pwquality.conf
    # - /etc/security/pwquality.conf.d/*.conf
    # "It is recommended that settings be configured in a .conf file in the /etc/security/pwquality.conf.d/ directory for clarity, convenience, and durability."

    if [ -d /etc/security/pwquality.conf.d ]; then
        for file in /etc/security/pwquality.conf.d/*.conf; do
            if grep -E "^[[:space:]]?enforce_for_root" "$file" >/dev/null 2>&1; then
                QUALITY_VALID=0
                ok "'pwquality' is enforced in '$file'"
            fi
        done
    fi

    if grep -E "^[[:space:]]?enforce_for_root" /etc/security/pwquality.conf >/dev/null 2>&1; then
        ok "'pwquality' is enforced for root in '/etc/security/pwquality.conf'"
        QUALITY_VALID=0
    fi

    if [ "$QUALITY_VALID" -ne 0 ]; then
        crit "'pwquality' is not enforced for root"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$QUALITY_VALID" -ne 0 ]; then
        echo "enforce_for_root" >>/etc/security/pwquality.conf
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
