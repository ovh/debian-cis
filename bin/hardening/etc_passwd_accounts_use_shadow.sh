#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure accounts in /etc/passwd use shadowed passwords (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=1
# shellcheck disable=2034
DESCRIPTION="Ensure accounts in /etc/passwd use shadowed passwords"
EXCEPTIONS=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    INVALID_USERS=""
    # Accounts with a shadowed password have an x in the second field in /etc/passwd.
    INVALID_USERS=$(awk -F: '($2 != "x" ) { print $1}' /etc/passwd)

    if [ -n "$INVALID_USERS" ]; then
        for user in $INVALID_USERS; do
            if [ -n "$EXCEPTIONS" ]; then
                if ! grep -w "$user" <<<"$EXCEPTIONS" >/dev/null; then
                    crit "$user does not use a shadow password"
                fi
            else
                crit "$user does not use a shadow password"
            fi
        done
    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    # the CIS recommendation says to "Analyze the output of the Audit step above and perform the appropriate action to correct
    #any discrepancies found."
    # so we do this manually instead of the recommended "automated"
    info "Please review the faulty accounts and update their password configuration, or set them as exceptions in the configuration"
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
