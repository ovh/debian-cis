#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password same consecutive characters is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password same consecutive characters is configured"

OPTIONS=''

# This function will be called if the script status is on enabled / audit mode
audit() {
    MAXREPEAT_PAM_WRONG_PARAMS=""
    # entries are "<param>=<value>:<file>"
    MAXREPEAT_CONF_WRONG_PARAMS=""
    local l_errors=0
    local l_pam_errors l_pam_values l_pam_value l_conf_value l_file

    # the configured values are maximums: compliant values are between 1 and the configured value
    # 0 disables the check, and is then not compliant
    for PW_OPT in $OPTIONS; do
        PW_PARAM=$(echo "$PW_OPT" | cut -d= -f1)
        PW_VALUE=$(echo "$PW_OPT" | cut -d= -f2)

        # a value set on the pam_pwquality line overrides pwquality.conf, check every PAM file
        l_pam_values=$(grep -Phs -- "^[[:space:]]*password[[:space:]]+[^#\n\r]+[[:space:]]+pam_pwquality\.so[[:space:]]+.*\b${PW_PARAM}[[:space:]]*=[[:space:]]*-?[0-9]+" /etc/pam.d/* | sed -E "s/.*\b${PW_PARAM}[[:space:]]*=[[:space:]]*(-?[0-9]+).*/\1/")
        if [ -n "$l_pam_values" ]; then
            l_pam_errors=0
            for l_pam_value in $l_pam_values; do
                if [ "$l_pam_value" -lt 1 ] || [ "$l_pam_value" -gt "$PW_VALUE" ]; then
                    crit "$PW_PARAM is overridden in /etc/pam.d with value $l_pam_value"
                    l_pam_errors=1
                fi
            done
            if [ "$l_pam_errors" -eq 0 ]; then
                ok "$PW_PARAM is correctly set in /etc/pam.d"
                continue
            fi
            MAXREPEAT_PAM_WRONG_PARAMS="$MAXREPEAT_PAM_WRONG_PARAMS $PW_PARAM"
            l_errors=1
        fi

        # without a valid PAM override (or once the wrong one is removed), the pwquality configuration applies
        # the last file of pwquality.conf.d setting the parameter wins over pwquality.conf
        l_file='/etc/security/pwquality.conf'
        if [ -d /etc/security/pwquality.conf.d ]; then
            if grep -E "^[[:space:]]?${PW_PARAM}" /etc/security/pwquality.conf.d/*.conf >/dev/null 2>&1; then
                l_file=$(grep -lE "^[[:space:]]?${PW_PARAM}" /etc/security/pwquality.conf.d/*.conf | sort -n | tail -n 1)
            fi
        fi

        l_conf_value=$(grep -Po -- "^[[:space:]]*${PW_PARAM}[[:space:]]*=[[:space:]]*\K-?[0-9]+" "$l_file" 2>/dev/null | tail -n 1)
        if [ -n "$l_conf_value" ] && [ "$l_conf_value" -ge 1 ] && [ "$l_conf_value" -le "$PW_VALUE" ]; then
            ok "$PW_PARAM = $l_conf_value is correctly set in $l_file"
        else
            crit "$PW_PARAM is not set to a value between 1 and $PW_VALUE in $l_file"
            MAXREPEAT_CONF_WRONG_PARAMS="$MAXREPEAT_CONF_WRONG_PARAMS ${PW_OPT}:${l_file}"
            l_errors=1
        fi
    done

    if [ "$l_errors" -eq 0 ]; then
        ok "password consecutive characters is correctly configured"
    else
        crit "password consecutive characters is not correctly configured"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    local l_entry l_file

    for l_entry in $MAXREPEAT_CONF_WRONG_PARAMS; do
        PW_OPT=${l_entry%%:*}
        l_file=${l_entry#*:}
        PW_PARAM=${PW_OPT%%=*}
        PW_VALUE=${PW_OPT#*=}
        info "setting $PW_PARAM = $PW_VALUE in $l_file"
        sed -E -i "/^[[:space:]]*${PW_PARAM}[[:space:]]*=/d" "$l_file"
        echo "$PW_PARAM = $PW_VALUE" >>"$l_file"
    done

    # the wrong PAM overrides take precedence over pwquality.conf, remove them
    for PW_PARAM in $MAXREPEAT_PAM_WRONG_PARAMS; do
        remove_pam_module_arg "pam_pwquality.so" "$PW_PARAM"
    done
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put your custom configuration here
# maximum allowed value, 0 (check disabled) is not compliant
OPTIONS="maxrepeat=3"
EOF
}

# This function will check config parameters required
check_config() {
    if [ -z "$OPTIONS" ]; then
        OPTIONS="maxrepeat=3"
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
