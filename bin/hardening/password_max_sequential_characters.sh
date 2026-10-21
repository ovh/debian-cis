#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password maximum sequential characters is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password maximum sequential characters is configured"

OPTIONS=''
FILE_QUALITY='/etc/security/pwquality.conf'

# This function will be called if the script status is on enabled / audit mode
audit() {
    MAXSEQUENCE_VALID=1

    for PW_OPT in $OPTIONS; do
        PW_PARAM=$(echo "$PW_OPT" | cut -d= -f1)
        PW_VALUE=$(echo "$PW_OPT" | cut -d= -f2)
        PAM_VALUE=""
        PAM_FOUND=1

        for file in /etc/pam.d/*; do
            if grep -PHs -- "^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\b${PW_PARAM}[[:space:]]*=[[:space:]]*[^[:space:]]+" "$file" >/dev/null 2>&1; then
                PAM_FOUND=0
                PAM_VALUE=$(grep -PHs -- "^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\b${PW_PARAM}[[:space:]]*=[[:space:]]*[^[:space:]]+" "$file" | sed -E "s/.*\b${PW_PARAM}[[:space:]]*=[[:space:]]*([^[:space:]]+).*/\1/" | head -n 1)
                break
            fi
        done

        if [ "$PAM_FOUND" -eq 0 ]; then
            if [ "$PAM_VALUE" = "$PW_VALUE" ]; then
                ok "$PW_PARAM=$PW_VALUE is correctly set in /etc/pam.d"
            else
                crit "$PW_PARAM is overridden in /etc/pam.d with value $PAM_VALUE"
                MAXSEQUENCE_VALID=0
            fi
            continue
        fi

        FILE_QUALITY='/etc/security/pwquality.conf'
        if [ -d /etc/security/pwquality.conf.d ]; then
            if grep -E "^[[:space:]]?${PW_PARAM}" /etc/security/pwquality.conf.d/*.conf >/dev/null 2>&1; then
                FILE_QUALITY=$(grep -lE "^[[:space:]]?${PW_PARAM}" /etc/security/pwquality.conf.d/*.conf | sort -n | tail -n 1)
            fi
        fi

        PATTERN="^${PW_PARAM}[[:space:]]?+=[[:space:]]?+$PW_VALUE"
        does_pattern_exist_in_file "$FILE_QUALITY" "$PATTERN"

        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN is present in $FILE_QUALITY"
        else
            crit "$PATTERN is not present in $FILE_QUALITY"
            MAXSEQUENCE_VALID=0
        fi
    done

    if [ "$MAXSEQUENCE_VALID" -eq 0 ]; then
        crit "password max sequential characters is not correctly configured"
    else
        ok "password max sequential characters is correctly configured"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    for PW_OPT in $OPTIONS; do
        PW_PARAM=$(echo "$PW_OPT" | cut -d= -f1)
        PW_VALUE=$(echo "$PW_OPT" | cut -d= -f2)
        PATTERN="^${PW_PARAM}[[:space:]]?+=[[:space:]]?+$PW_VALUE"
        does_pattern_exist_in_file "$FILE_QUALITY" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            ok "$PATTERN is present in $FILE_QUALITY"
        else
            warn "$PATTERN is not present in $FILE_QUALITY, adding it"
            does_pattern_exist_in_file "$FILE_QUALITY" "^${PW_PARAM}"
            if [ "$FNRET" != 0 ]; then
                add_end_of_file "$FILE_QUALITY" "$PW_PARAM = $PW_VALUE"
            else
                info "Parameter $PW_PARAM is present but with the wrong value -- Fixing"
                replace_in_file "$FILE_QUALITY" "^${PW_PARAM}*.*" "$PW_PARAM = $PW_VALUE"
            fi
        fi
    done

    # apply() must clean the effective PAM line and the generated profile used by pam-auth-update
    if [ "$MAXSEQUENCE_VALID" -eq 0 ]; then
        for file in /etc/pam.d/* /usr/share/pam-configs/*; do
            [ -e "$file" ] || continue
            if grep -PHs -- "^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\bmaxsequence[[:space:]]*=[[:space:]]*[^[:space:]]+" "$file" >/dev/null 2>&1; then
                sed -E -i 's/maxsequence[[:space:]]*=[[:space:]]*[0-9]+//g' "$file"
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
OPTIONS="maxsequence=3"
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
