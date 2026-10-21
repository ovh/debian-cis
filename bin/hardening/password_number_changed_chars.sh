#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password number of changed characters is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password number of changed characters is configured"

OPTIONS=''

# This function will be called if the script status is on enabled / audit mode
audit() {
    QUALITY_VALID=1
    DIFOK_IN_PAM=1
    PAM_DIFOK_VALUE=""

    # order of override from strongest to latest:
    # - /etc/pam.d/*
    # - /etc/security/pwquality.conf
    # - /etc/security/pwquality.conf.d/*.conf
    # In Debian, a direct pam_pwquality line in /etc/pam.d/common-password overrides the generic pwquality defaults.
    # "It is recommended that settings be configured in a .conf file in the /etc/security/pwquality.conf.d/ directory for clarity, convenience, and durability."
    expected_value=$(awk -F '=' '{print $2}' <<<"$OPTIONS")

    local difok_value=""
    DIFOK_FILE="/etc/security/pwquality.conf"

    if [ -d /etc/security/pwquality.conf.d ]; then
        if grep -E "^[[:space:]]?difok" /etc/security/pwquality.conf.d/*.conf >/dev/null 2>&1; then
            # if set in many places, the latest one is the one used
            DIFOK_FILE=$(grep -lE "^[[:space:]]?difok" /etc/security/pwquality.conf.d/*.conf | sort -n | tail -n 1)
        fi
    fi

    # maybe absent from /etc/security/pwquality.conf
    if grep -E "^[[:space:]]?difok" "$DIFOK_FILE" >/dev/null 2>&1; then
        difok_value=$(grep -E "^[[:space:]]?difok" "$DIFOK_FILE" | awk -F '=' '{print $2}' | sed 's/\ *//g' | tail -n 1)
        info "current 'pwquality difok' value = $difok_value"
    fi

    for file in /etc/pam.d/*; do
        if grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bdifok[[:space:]]*=[[:space:]]*[0-9]+' "$file" >/dev/null 2>&1; then
            PAM_DIFOK_VALUE=$(grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bdifok[[:space:]]*=[[:space:]]*[0-9]+' "$file" | sed -E 's/.*\bdifok[[:space:]]*=[[:space:]]*([0-9]+).*/\1/' | head -n 1)
            DIFOK_IN_PAM=0
            break
        fi
    done

    if [ "$DIFOK_IN_PAM" -eq 0 ]; then
        for file in /etc/pam.d/* /usr/share/pam-configs/*; do
            [ -e "$file" ] || continue
            if grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bdifok[[:space:]]*=[[:space:]]*[0-9]+' "$file" >/dev/null 2>&1; then
                sed -E -i 's/([[:space:]])difok[[:space:]]*=[[:space:]]*[0-9]+//g; s/(pam_pwquality\.so)([[:space:]]+.*)[[:space:]]difok[[:space:]]*=[[:space:]]*[0-9]+/\1\2/g' "$file"
            fi
        done
        if grep -ql 'pam_pwquality.so' /usr/share/pam-configs/* 2>/dev/null; then
            while IFS= read -r profile; do
                DEBIAN_FRONTEND=noninteractive pam-auth-update --force --enable "$(basename "$profile")"
            done < <(grep -l 'pam_pwquality.so' /usr/share/pam-configs/* 2>/dev/null | sort -u)
        fi
    fi

    if [ "$DIFOK_IN_PAM" -eq 0 ]; then
        if [ "$PAM_DIFOK_VALUE" = "$expected_value" ]; then
            QUALITY_VALID=0
        fi
    elif [ -n "$difok_value" ] && [ "$difok_value" -eq "$expected_value" ]; then
        QUALITY_VALID=0
    fi

    if [ "$QUALITY_VALID" -eq 0 ]; then
        ok "pwquality 'difok' value is correctly configured"
    else
        crit "pwquality 'difok' value is not correctly configured"
    fi

    if [ "$DIFOK_IN_PAM" -eq 0 ] && [ "$PAM_DIFOK_VALUE" != "$expected_value" ]; then
        crit "pwquality 'difok' is overridden in PAM configuration with value $PAM_DIFOK_VALUE"
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$QUALITY_VALID" -ne 0 ]; then
        sed -E -i '/^[[:space:]]?difok/d' "$DIFOK_FILE"
        echo "$OPTIONS" >>"$DIFOK_FILE"
    fi

    if [ "$DIFOK_IN_PAM" -eq 0 ]; then
        for file in /etc/pam.d/* /usr/share/pam-configs/*; do
            [ -e "$file" ] || continue
            if grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bdifok[[:space:]]*=[[:space:]]*[0-9]+' "$file" >/dev/null 2>&1; then
                sed -E -i 's/([[:space:]])difok[[:space:]]*=[[:space:]]*[0-9]+//g; s/(pam_pwquality\.so)([[:space:]]+.*)[[:space:]]difok[[:space:]]*=[[:space:]]*[0-9]+/\1\2/g' "$file"
            fi
        done
        if grep -ql 'pam_pwquality.so' /usr/share/pam-configs/* 2>/dev/null; then
            while IFS= read -r profile; do
                DEBIAN_FRONTEND=noninteractive pam-auth-update --force --enable "$(basename "$profile")"
            done < <(grep -l 'pam_pwquality.so' /usr/share/pam-configs/* 2>/dev/null | sort -u)
        fi
    fi

}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put your custom configuration here
OPTIONS="difok=3"
EOF
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
