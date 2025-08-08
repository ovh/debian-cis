#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password failed attempts lockout is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure password failed attempts lockout is configured"

MAX_ATTEMPT=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    PASSWORD_LOCKOUT=0
    LOCKOUT_IN_PAM=1

    # we want it to be set expliciteley, to avoid a default value changing from one version to another
    if ! grep -Pi -- "^\h*deny\h*=\h*[1-$MAX_ATTEMPT]\b" /etc/security/faillock.conf; then
        crit "password lockout is misconfigured in /etc/security/faillock.conf"
        PASSWORD_LOCKOUT=1
    else
        info "password lockout is correctly configured in /etc/security/faillock.conf"
    fi

    for file in /usr/share/pam-configs/*; do
        if grep -Pi -- "^\h*auth\h+(requisite|required|sufficient)\h+pam_faillock\.so\h+([^#\n\r]+\h+)?deny\h*=\h*[0-9]+\b" "$file" >/dev/null 2>&1; then
            LOCKOUT_IN_PAM=0
            break
        fi
    done

    if [ "$LOCKOUT_IN_PAM" -eq 0 ]; then
        # configuration in pam is going to override the one in /etc/security/faillock.conf
        crit "password lockout is configured in /usr/share/pam-configs"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PASSWORD_LOCKOUT" -ne 0 ]; then
        info "update 'deny' parameter in /etc/security/faillock.conf"
        sed -i '/^[[:space:]]?deny/d' /etc/security/faillock.conf
        echo "deny = $MAX_ATTEMPT" >>/etc/security/faillock.conf
    fi

    if [ "$LOCKOUT_IN_PAM" -eq 0 ]; then
        for file in /usr/share/pam-configs/*; do
            if grep -Pi -- "^\h*auth\h+(requisite|required|sufficient)\h+pam_faillock\.so\h+([^#\n\r]+\h+)?deny\h*=\h*[0-9]+\b" "$file" >/dev/null 2>&1; then
                info "Remove 'deny' configuration in $file"
                sed -E -i 's/deny[[:space:]]?=[[:space:]]?[0-9]+//g' "$file"
            fi
        done

    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# max attempts before locking the account
MAX_ATTEMPT=5
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
