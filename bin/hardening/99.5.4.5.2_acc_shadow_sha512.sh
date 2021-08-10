#!/bin/bash

# run-shellcheck
#
# OVH Security audit
#

#
# 99.5.4.5.2 Check that any password that may exist in /etc/shadow is SHA512 hashed and salted
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Check that any password that may exist in /etc/shadow is SHA512 hashed and salted"
FILE="/etc/shadow"

# This function will be called if the script status is on enabled / audit mode
audit() {
    # Review shadow file for existing passwords
    pw_found=""
    users_reviewed=""
    if $SUDO_CMD [ ! -r "$FILE" ]; then
        crit "$FILE is not readable"
        return
    fi
    for line in $($SUDO_CMD cut -d ":" -f 1,2 /etc/shadow); do
        users_reviewed+="$line "
        user=$(echo "$line" | cut -d ":" -f 1)
        passwd=$(echo "$line" | cut -d ":" -f 2)
        if [[ $passwd = '!' || $passwd = '*' ]]; then
            continue
        elif [[ $passwd =~ ^!.*$ ]]; then
            pw_found+="$user "
            ok "User $user has a disabled password."
        # Check password against $6$<salt>$<encrypted>, see `man 3 crypt`
        elif [[ $passwd =~ ^\$6(\$rounds=[0-9]+)?\$[a-zA-Z0-9./]{2,16}\$[a-zA-Z0-9./]{86}$ ]]; then
            pw_found+="$user "
            ok "User $user has suitable SHA512 hashed password."
        else
            pw_found+="$user "
            crit "User $user has a password that is not SHA512 hashed."
        fi
    done
    if [[ -z "$users_reviewed" ]]; then
        crit "No users were reviewed in $FILE !"
        return
    fi
    if [[ -z "$pw_found" ]]; then
        ok "There is no password in $FILE"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    :
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
if [ -z "$CIS_ROOT_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "$CIS_ROOT_DIR"/lib/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "$CIS_ROOT_DIR"/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
