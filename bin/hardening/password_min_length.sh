#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure minimum password length is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password minimum length is configured "

OPTIONS=''
FILE_QUALITY='/etc/security/pwquality.conf'

# This function will be called if the script status is on enabled / audit mode
audit() {
    MINLEN_VALID=1
    MINLEN_IN_PAM=1
    PAM_MINLEN_VALUE=""

    # order of override from strongest to latest:
    # - /etc/pam.d/*
    # - /etc/security/pwquality.conf
    # - /etc/security/pwquality.conf.d/*.conf
    # A direct pam_pwquality line in /etc/pam.d/common-password overrides the generic pwquality defaults.
    expected_value=$(awk -F '=' '{print $2}' <<<"$OPTIONS")

    local minlen_value=""
    FILE_QUALITY='/etc/security/pwquality.conf'

    if [ -d /etc/security/pwquality.conf.d ]; then
        if grep -E "^[[:space:]]?minlen" /etc/security/pwquality.conf.d/*.conf >/dev/null 2>&1; then
            FILE_QUALITY=$(grep -lE "^[[:space:]]?minlen" /etc/security/pwquality.conf.d/*.conf | sort -n | tail -n 1)
        fi
    fi

    if grep -E "^[[:space:]]?minlen" "$FILE_QUALITY" >/dev/null 2>&1; then
        minlen_value=$(grep -E "^[[:space:]]?minlen" "$FILE_QUALITY" | awk -F '=' '{print $2}' | sed 's/\ *//g' | tail -n 1)
        info "current 'pwquality minlen' value = $minlen_value"
    fi

    for file in /etc/pam.d/*; do
        if grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bminlen[[:space:]]*=[[:space:]]*[0-9]+' "$file" >/dev/null 2>&1; then
            PAM_MINLEN_VALUE=$(grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bminlen[[:space:]]*=[[:space:]]*[0-9]+' "$file" | sed -E 's/.*\bminlen[[:space:]]*=[[:space:]]*([0-9]+).*/\1/' | head -n 1)
            MINLEN_IN_PAM=0
            break
        fi
    done

    if [ "$MINLEN_IN_PAM" -eq 0 ]; then
        for file in /etc/pam.d/* /usr/share/pam-configs/*; do
            [ -e "$file" ] || continue
            if grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bminlen[[:space:]]*=[[:space:]]*[0-9]+' "$file" >/dev/null 2>&1; then
                sed -E -i 's/([[:space:]])minlen[[:space:]]*=[[:space:]]*[0-9]+//g; s/(pam_pwquality\.so)([[:space:]]+.*)[[:space:]]minlen[[:space:]]*=[[:space:]]*[0-9]+/\1\2/g' "$file"
            fi
        done
        if grep -ql 'pam_pwquality.so' /usr/share/pam-configs/* 2>/dev/null; then
            while IFS= read -r profile; do
                DEBIAN_FRONTEND=noninteractive pam-auth-update --force --enable "$(basename "$profile")"
            done < <(grep -l 'pam_pwquality.so' /usr/share/pam-configs/* 2>/dev/null | sort -u)
        fi
    fi

    if [ "$MINLEN_IN_PAM" -eq 0 ]; then
        if [ "$PAM_MINLEN_VALUE" = "$expected_value" ]; then
            MINLEN_VALID=0
        fi
    elif [ -n "$minlen_value" ] && [ "$minlen_value" -eq "$expected_value" ]; then
        MINLEN_VALID=0
    fi

    if [ "$MINLEN_VALID" -eq 0 ]; then
        ok "pwquality 'minlen' value is correctly configured"
    else
        crit "pwquality 'minlen' value is not correctly configured"
    fi

    if [ "$MINLEN_IN_PAM" -eq 0 ] && [ "$PAM_MINLEN_VALUE" != "$expected_value" ]; then
        crit "pwquality 'minlen' is overridden in PAM configuration with value $PAM_MINLEN_VALUE"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$MINLEN_VALID" -ne 0 ]; then
        sed -E -i '/^[[:space:]]?minlen/d' "$FILE_QUALITY"
        echo "$OPTIONS" >>"$FILE_QUALITY"
    fi

    if [ "$MINLEN_IN_PAM" -eq 0 ]; then
        for file in /etc/pam.d/* /usr/share/pam-configs/*; do
            [ -e "$file" ] || continue
            if grep -PHs -- '^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bminlen[[:space:]]*=[[:space:]]*[0-9]+' "$file" >/dev/null 2>&1; then
                sed -E -i 's/([[:space:]])minlen[[:space:]]*=[[:space:]]*[0-9]+//g; s/(pam_pwquality\.so)([[:space:]]+.*)[[:space:]]minlen[[:space:]]*=[[:space:]]*[0-9]+/\1\2/g' "$file"
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
OPTIONS="minlen=14"
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
