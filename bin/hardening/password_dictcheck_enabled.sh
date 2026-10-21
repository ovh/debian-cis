#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password dictionary check is enabled (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password dictionary check is enabled"
# 'dictcheck=0' will disable the dictionnary check
EXPECTED_VALUE=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    QUALITY_VALID=1
    DICTCHECK_IN_PAM=1
    PAM_DICTCHECK_VALUE=""

    # order of override from strongest to latest:
    # - /etc/pam.d/*
    # - /etc/security/pwquality.conf
    # - /etc/security/pwquality.conf.d/*.conf
    # A direct pam_pwquality line in /etc/pam.d/common-password overrides the generic pwquality defaults.
    local dictcheck_value=""
    DICTCHECK_FILE="/etc/security/pwquality.conf"

    if [ -d /etc/security/pwquality.conf.d ]; then
        if grep -E "^[[:space:]]?dictcheck" /etc/security/pwquality.conf.d/*.conf >/dev/null 2>&1; then
            DICTCHECK_FILE=$(grep -lE "^[[:space:]]?dictcheck" /etc/security/pwquality.conf.d/*.conf | sort -n | tail -n 1)
        fi
    fi

    if grep -E "^[[:space:]]?dictcheck" "$DICTCHECK_FILE" >/dev/null 2>&1; then
        dictcheck_value=$(grep -E "^[[:space:]]?dictcheck" "$DICTCHECK_FILE" | awk -F '=' '{print $2}' | sed 's/\ *//g' | tail -n 1)
        info "current 'pwquality dictcheck' value = $dictcheck_value"
    fi

    for file in /etc/pam.d/*; do
        if grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bdictcheck[[:space:]]*=[[:space:]]*[0-9]+' "$file" >/dev/null 2>&1; then
            PAM_DICTCHECK_VALUE=$(grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bdictcheck[[:space:]]*=[[:space:]]*[0-9]+' "$file" | sed -E 's/.*\bdictcheck[[:space:]]*=[[:space:]]*([0-9]+).*/\1/' | head -n 1)
            DICTCHECK_IN_PAM=0
            break
        fi
    done

    if [ "$DICTCHECK_IN_PAM" -eq 0 ]; then
        if [ "$PAM_DICTCHECK_VALUE" = "$EXPECTED_VALUE" ]; then
            QUALITY_VALID=0
        fi
    elif [ -n "$dictcheck_value" ] && [ "$dictcheck_value" -eq "$EXPECTED_VALUE" ]; then
        QUALITY_VALID=0
    fi

    if [ "$QUALITY_VALID" -eq 0 ]; then
        ok "pwquality 'dictcheck' value is correctly configured"
    else
        crit "pwquality 'dictcheck' value is not correctly configured"
    fi

    if [ "$DICTCHECK_IN_PAM" -eq 0 ] && [ "$PAM_DICTCHECK_VALUE" != "$EXPECTED_VALUE" ]; then
        crit "pwquality 'dictcheck' is overridden in PAM configuration with value $PAM_DICTCHECK_VALUE"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$QUALITY_VALID" -ne 0 ]; then
        sed -E -i '/^[[:space:]]?dictcheck/d' "$DICTCHECK_FILE"
        echo "dictcheck=$EXPECTED_VALUE" >>"$DICTCHECK_FILE"
    fi

    if [ "$DICTCHECK_IN_PAM" -eq 0 ]; then
        for file in /etc/pam.d/* /usr/share/pam-configs/*; do
            [ -e "$file" ] || continue
            if grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bdictcheck[[:space:]]*=[[:space:]]*[0-9]+' "$file" >/dev/null 2>&1; then
                sed -E -i 's/([[:space:]])dictcheck[[:space:]]*=[[:space:]]*[0-9]+//g; s/(pam_pwquality\.so)([[:space:]]+.*)[[:space:]]dictcheck[[:space:]]*=[[:space:]]*[0-9]+/\1\2/g' "$file"
            fi
        done
        if grep -ql 'pam_pwquality.so' /usr/share/pam-configs/* 2>/dev/null; then
            while IFS= read -r profile; do
                DEBIAN_FRONTEND=noninteractive pam-auth-update --force --enable "$(basename "$profile")"
            done < <(grep -l 'pam_pwquality.so' /usr/share/pam-configs/* 2>/dev/null | sort -u)
        fi
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
