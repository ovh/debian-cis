#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure /etc/shadow password fields are not empty (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure /etc/shadow password fields are not empty"
EXCEPTIONS=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    INVALID_USERS=""

    local tmp_invalid_users=""
    tmp_invalid_users=$($SUDO_CMD cat /etc/shadow | awk -F: '($2 == "" ) { print $1 }')

    if [ -n "$tmp_invalid_users" ]; then
        for user in $tmp_invalid_users; do
            if [ -n "$EXCEPTIONS" ]; then
                if ! grep -w "$user" <<<"$EXCEPTIONS" >/dev/null; then
                    crit "$user does not have a password"
                    INVALID_USERS="$INVALID_USERS $user"
                fi
            else
                crit "$user does not have a password"
                INVALID_USERS="$INVALID_USERS $user"
            fi
        done
    fi

}

# This function will be called if the script status is on enabled mode
apply() {

    if [ -n "$INVALID_USERS" ]; then
        for user in $INVALID_USERS; do
            info "locking $user"
            passwd -l "$user"
        done
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# maybe someone is gonna have a legit use case....
create_config() {
    cat <<EOF
# shellcheck disable=2034
status=audit
# Put here the accounts that should keep their non shadowed password
EXCEPTIONS=''
EOF
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
