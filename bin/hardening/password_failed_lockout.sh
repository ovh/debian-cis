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
    LOCKOUT_PAM_INVALID=1
    local l_conf_deny l_pam_value

    # we want it to be set explicitly, to avoid a default value changing from one version to another
    # deny=0 disables the lockout, and the last value set in the file wins
    l_conf_deny=$(grep -Pi -- '^\h*deny\h*=\h*[0-9]+\b' /etc/security/faillock.conf 2>/dev/null | tail -n 1 | sed -E 's/^[^=]*=[[:space:]]*([0-9]+).*/\1/')
    if [ -n "$l_conf_deny" ] && [ "$l_conf_deny" -ge 1 ] && [ "$l_conf_deny" -le "$MAX_ATTEMPT" ]; then
        info "password lockout is correctly configured in /etc/security/faillock.conf"
    else
        crit "password lockout is misconfigured in /etc/security/faillock.conf"
        PASSWORD_LOCKOUT=1
    fi

    # a value set on the pam_faillock line overrides faillock.conf, check every PAM file
    while IFS= read -r l_pam_value; do
        if [ "$l_pam_value" -ge 1 ] && [ "$l_pam_value" -le "$MAX_ATTEMPT" ]; then
            ok "password lockout is correctly configured in /etc/pam.d"
        else
            crit "password lockout is overridden in /etc/pam.d with value $l_pam_value"
            LOCKOUT_PAM_INVALID=0
        fi
    done < <(grep -Pih -- '^\h*auth\h+(requisite|required|sufficient)\h+pam_faillock\.so\h+([^#\n\r]+\h+)?deny\h*=\h*[0-9]+\b' /etc/pam.d/* | sed -E 's/.*deny[[:space:]]*=[[:space:]]*([0-9]+).*/\1/')
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PASSWORD_LOCKOUT" -ne 0 ]; then
        info "update 'deny' parameter in /etc/security/faillock.conf"
        sed -E -i '/^[[:space:]]*deny[[:space:]]*=/d' /etc/security/faillock.conf
        echo "deny = $MAX_ATTEMPT" >>/etc/security/faillock.conf
    fi

    if [ "$LOCKOUT_PAM_INVALID" -eq 0 ]; then
        remove_pam_module_arg "pam_faillock.so" "deny"
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
    if [ -z "$MAX_ATTEMPT" ]; then
        MAX_ATTEMPT=5
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
