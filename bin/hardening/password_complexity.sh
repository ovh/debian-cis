#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password complexity is configured (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password complexity is configured"

OPTIONS=''
FILE_QUALITY='/etc/security/pwquality.conf'

# This function will be called if the script status is on enabled / audit mode
audit() {
    COMPLEXITY_PAM_WRONG_PARAMS=""
    local l_errors=0
    local l_pam_errors l_pam_values l_pam_value

    for PW_OPT in $OPTIONS; do
        PW_PARAM=$(echo "$PW_OPT" | cut -d= -f1)
        PW_VALUE=$(echo "$PW_OPT" | cut -d= -f2)

        # a value set on the pam_pwquality line overrides pwquality.conf, check every PAM file
        l_pam_values=$(grep -Phs -- "^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\b${PW_PARAM}[[:space:]]*=[[:space:]]*[^[:space:]]+" /etc/pam.d/* | sed -E "s/.*\b${PW_PARAM}[[:space:]]*=[[:space:]]*([^[:space:]]+).*/\1/")
        if [ -n "$l_pam_values" ]; then
            l_pam_errors=0
            for l_pam_value in $l_pam_values; do
                if [ "$l_pam_value" != "$PW_VALUE" ]; then
                    crit "$PW_PARAM is overridden in /etc/pam.d with value $l_pam_value"
                    l_pam_errors=1
                fi
            done
            if [ "$l_pam_errors" -eq 0 ]; then
                ok "$PW_PARAM=$PW_VALUE is correctly set in /etc/pam.d"
            else
                COMPLEXITY_PAM_WRONG_PARAMS="$COMPLEXITY_PAM_WRONG_PARAMS $PW_PARAM"
                l_errors=1
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
            l_errors=1
        fi
    done

    if [ "$l_errors" -eq 0 ]; then
        ok "password complexity is correctly configured"
    else
        crit "password complexity is not correctly configured"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "The values defined here should be adapted to one needs before applying."
    # only the wrong PAM overrides are removed, pwquality.conf has to be configured manually
    for PW_PARAM in $COMPLEXITY_PAM_WRONG_PARAMS; do
        remove_pam_module_arg "pam_pwquality.so" "$PW_PARAM"
    done
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put your custom configuration here
OPTIONS="minclass=3 dcredit=-1 ucredit=-2 ocredit=-1 lcredit=-1"
EOF
}

# This function will check config parameters required
check_config() {
    if [ -z "$OPTIONS" ]; then
        OPTIONS="minclass=3 dcredit=-1 ucredit=-2 ocredit=-1 lcredit=-1"
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
