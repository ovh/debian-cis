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
MAX_UNLOCK_TIME=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    UNLOCK_TIME_VALID=1
    UNLOCK_IN_PAM=1
    PAM_UNLOCK_TIME=""

    # we want it to be set explicitly, to avoid a default value changing from one version to another
    if grep -E "^[[:space:]]?unlock_time" "$CONF_FILE" >/dev/null 2>&1; then
        local current_unlock_time=""
        current_unlock_time=$(awk -F '=' '/^[[:space:]]?unlock_time/ {print $2}' "$CONF_FILE" | sed 's/[[:space:]]//g')
        if [ "$current_unlock_time" -le "$MAX_UNLOCK_TIME" ]; then
            UNLOCK_TIME_VALID=0
        fi
    fi

    for file in /etc/pam.d/*; do
        if grep -Pih -- '^[[:space:]]*auth[[:space:]]+[^#\n\r]+[[:space:]]+pam_faillock\.so[[:space:]]+.*\bunlock_time[[:space:]]*=[[:space:]]*[0-9]+' "$file" >/dev/null 2>&1; then
            PAM_UNLOCK_TIME=$(grep -Pih -- '^[[:space:]]*auth[[:space:]]+[^#\n\r]+[[:space:]]+pam_faillock\.so[[:space:]]+.*\bunlock_time[[:space:]]*=[[:space:]]*[0-9]+' "$file" | sed -E 's/.*\bunlock_time[[:space:]]*=[[:space:]]*([0-9]+).*/\1/' | head -n 1)
            UNLOCK_IN_PAM=0
            break
        fi
    done

    if [ "$UNLOCK_TIME_VALID" -eq 0 ]; then
        ok "password 'unlock_time' is correctly configured"
    else
        crit "password 'unlock_time' is not correctly configured"
    fi

    if [ "$UNLOCK_IN_PAM" -eq 0 ]; then
        if [ "$PAM_UNLOCK_TIME" -le "$MAX_UNLOCK_TIME" ]; then
            ok "unlock_time is correctly configured in /etc/pam.d"
        else
            crit "unlock_time is overridden in /etc/pam.d with value $PAM_UNLOCK_TIME"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$UNLOCK_TIME_VALID" -ne 0 ]; then
        sed -E -i '/^[[:space:]]?unlock_time/d' "$CONF_FILE"
        echo "unlock_time = $MAX_UNLOCK_TIME" >>"$CONF_FILE"
    fi

    if [ "$UNLOCK_IN_PAM" -eq 0 ]; then
        for file in /etc/pam.d/* /usr/share/pam-configs/*; do
            [ -e "$file" ] || continue
            if grep -Pih -- '^[[:space:]]*auth[[:space:]]+[^#\n\r]+[[:space:]]+pam_faillock\.so[[:space:]]+.*\bunlock_time[[:space:]]*=[[:space:]]*[0-9]+' "$file" >/dev/null 2>&1; then
                sed -E -i 's/unlock_time[[:space:]]*=[[:space:]]*[0-9]+//g' "$file"
            fi
        done
        if grep -ql 'pam_faillock.so' /usr/share/pam-configs/* 2>/dev/null; then
            while IFS= read -r profile; do
                DEBIAN_FRONTEND=noninteractive pam-auth-update --force --enable "$(basename "$profile")"
            done < <(grep -l 'pam_faillock.so' /usr/share/pam-configs/* 2>/dev/null | sort -u)
        fi
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# time in seconds before unlocking account
# 0 = never, which can lead to some kind of denial of service
MAX_UNLOCK_TIME=900
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
