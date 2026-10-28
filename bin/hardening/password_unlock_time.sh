#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password unlock time is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password unlock time is configured"
CONF_FILE="/etc/security/faillock.conf"
MIN_UNLOCK_TIME=""
# former name of MIN_UNLOCK_TIME, still honored for existing configurations
MAX_UNLOCK_TIME=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    UNLOCK_TIME_VALID=1
    UNLOCK_PAM_INVALID=1
    local l_pam_value
    local l_conf_value

    # compliant values are 0 (never unlock) or at least MIN_UNLOCK_TIME
    # we want it to be set explicitly, to avoid a default value changing from one version to another
    l_conf_value=$(grep -Po '^[[:space:]]*unlock_time[[:space:]]*=[[:space:]]*\K[0-9]+' "$CONF_FILE" 2>/dev/null | tail -n 1)
    if [ -n "$l_conf_value" ]; then
        if [ "$l_conf_value" -eq 0 ] || [ "$l_conf_value" -ge "$MIN_UNLOCK_TIME" ]; then
            UNLOCK_TIME_VALID=0
        fi
    fi

    if [ "$UNLOCK_TIME_VALID" -eq 0 ]; then
        ok "password 'unlock_time' is correctly configured"
    else
        crit "password 'unlock_time' is not correctly configured"
    fi

    # a value set on the pam_faillock line overrides faillock.conf, check every PAM file
    # (\b excludes root_unlock_time, handled by password_root_unlock.sh)
    while IFS= read -r l_pam_value; do
        if [ "$l_pam_value" -eq 0 ] || [ "$l_pam_value" -ge "$MIN_UNLOCK_TIME" ]; then
            ok "unlock_time is correctly configured in /etc/pam.d"
        else
            crit "unlock_time is overridden in /etc/pam.d with value $l_pam_value"
            UNLOCK_PAM_INVALID=0
        fi
    done < <(grep -Pih -- '^[[:space:]]*auth[[:space:]]+[^#\n\r]+[[:space:]]+pam_faillock\.so[[:space:]]+.*\bunlock_time[[:space:]]*=[[:space:]]*[0-9]+' /etc/pam.d/* | sed -E 's/.*\bunlock_time[[:space:]]*=[[:space:]]*([0-9]+).*/\1/')
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$UNLOCK_TIME_VALID" -ne 0 ]; then
        sed -E -i '/^[[:space:]]*unlock_time/d' "$CONF_FILE"
        echo "unlock_time = $MIN_UNLOCK_TIME" >>"$CONF_FILE"
    fi

    if [ "$UNLOCK_PAM_INVALID" -eq 0 ]; then
        remove_pam_module_arg "pam_faillock.so" "unlock_time"
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# minimum time in seconds before a locked account is unlocked
# 0 (never unlock) is also accepted, but can lead to some kind of denial of service
MIN_UNLOCK_TIME=900
EOF
}

# This function will check config parameters required
check_config() {
    if [ -z "$MIN_UNLOCK_TIME" ]; then
        MIN_UNLOCK_TIME="${MAX_UNLOCK_TIME:-900}"
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
