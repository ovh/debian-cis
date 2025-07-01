#!/bin/bash

# run-shellcheck
#
# OVH Security audit
#

#
# Check that passwords in /etc/shadow are sha512crypt (or yescrypt for Debian 11+) hashed and salted
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Check that passwords in /etc/shadow are sha512crypt (or yescrypt for Debian 11+) hashed and salted"
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
        # yescrypt: Check password against $y$<salt>$<base64>
        elif [ "$DEB_MAJ_VER" -ge "11" ] && [[ $passwd =~ ^\$y\$[./A-Za-z0-9]+\$[./A-Za-z0-9]{,86}\$[./A-Za-z0-9]{43} ]]; then
            pw_found+="$user "
            ok "User $user has suitable yescrypt hashed password."
        # sha512: Check password against $6$<salt>$<base64>, see `man 3 crypt`
        elif [[ $passwd =~ ^\$6(\$rounds=[0-9]+)?\$[a-zA-Z0-9./]{2,16}\$[a-zA-Z0-9./]{86}$ ]]; then
            pw_found+="$user "
            ok "User $user has suitable sha512crypt hashed password."
        else
            pw_found+="$user "
            if [ "$DEB_MAJ_VER" -ge "11" ]; then
                crit "User $user has a password that is not sha512crypt nor yescrypt hashed."
            else
                crit "User $user has a password that is not sha512crypt hashed."
            fi
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
