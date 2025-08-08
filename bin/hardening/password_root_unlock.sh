#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password failed attempts lockout includes root account (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password failed attempts lockout includes root account"
CONF_FILE="/etc/security/faillock.conf"
MAX_UNLOCK_TIME=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    ROOT_UNLOCK_VALID=1
    ROOT_UNLOCK_IN_PAM=1

    # we want it to be set expliciteley, to avoid a default value changing from one version to another
    # if 'even_deny_root' is configured, then unlock_time is the same as others users
    # this value is then checked by the 'password_unlock_time.sh' check
    if grep "^[^#]*even_deny_root" "$CONF_FILE"; then
        ROOT_UNLOCK_VALID=0
    # if 'even_deny_root' is not set, check for 'root_unlock_time', which implies the former
    elif grep "^[^#]*root_unlock_time" "$CONF_FILE"; then
        local current_unlock_time=""
        current_unlock_time=$(awk -F '=' '/^[^#]*root_unlock_time/ {print $2}' "$CONF_FILE")
        if [ "$current_unlock_time" -le "$MAX_UNLOCK_TIME" ]; then
            ROOT_UNLOCK_VALID=0
        fi
    fi

    if [ "$ROOT_UNLOCK_VALID" -eq 0 ]; then
        ok "root password unlock is correctly configured"
    else
        crit "root password unlock  is not correctly configured"
    fi

    for file in /usr/share/pam-configs/*; do
        if grep -Pi -- '^\h*auth\h+([^#\n\r]+\h+)pam_faillock\.so\h+([^#\n\r]+\h+)?root_unlock_time\b' "$file" >/dev/null 2>&1; then
            ROOT_UNLOCK_IN_PAM=0
            break
        fi
    done

    if [ "$ROOT_UNLOCK_IN_PAM" -eq 0 ]; then
        # configuration in pam is going to override the one in /etc/security/faillock.conf
        crit "password root_unlock_time is configured in /usr/share/pam-configs"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$ROOT_UNLOCK_VALID" -ne 0 ]; then
        sed -E -i '/^[[:space:]]?root_unlock_time/d' "$CONF_FILE"
        echo "root_unlock_time = $MAX_UNLOCK_TIME" >>"$CONF_FILE"
    fi

    if [ "$ROOT_UNLOCK_IN_PAM" -eq 0 ]; then
        for file in /usr/share/pam-configs/*; do
            if grep -Pi -- '^\h*auth\h+([^#\n\r]+\h+)pam_faillock\.so\h+([^#\n\r]+\h+)?root_unlock_time\b' "$file" >/dev/null 2>&1; then
                info "Remove 'unlock_time' configuration in $file"
                sed -E -i 's/root_unlock_time[[:space:]]?=[[:space:]]?[0-9]+//g' "$file"
            fi
        done
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# time in seconds before unlocking account
# 0 = never, which can lead to some kind of denial of service
MAX_UNLOCK_TIME=60
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
