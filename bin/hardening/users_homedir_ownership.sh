#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure users own their home directories (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure users own their home directories"

EXCEPTIONS=""

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    RESULT=$(awk -F: '{ print $1 ":" $3 ":" $6 }' /etc/passwd)
    for LINE in $RESULT; do
        debug "Working on $LINE"
        USER=$(awk -F: '{print $1}' <<<"$LINE")
        USERID=$(awk -F: '{print $2}' <<<"$LINE")
        DIR=$(awk -F: '{print $3}' <<<"$LINE")
        if [ "$USERID" -ge 1000 ] && [ -d "$DIR" ] && [ "$USER" != "nfsnobody" ]; then
            OWNER=$(stat -L -c "%U" "$DIR")
            if [ "$OWNER" != "$USER" ]; then
                EXCEP_FOUND=0
                for excep in $EXCEPTIONS; do
                    if [ "$DIR:$USER:$OWNER" = "$excep" ]; then
                        ok "The home directory ($DIR) of user $USER is owned by $OWNER but is part of exceptions ($DIR:$USER:$OWNER)."
                        EXCEP_FOUND=1
                        break
                    fi
                done
                if [ "$EXCEP_FOUND" -eq 0 ]; then
                    crit "The home directory ($DIR) of user $USER is owned by $OWNER."
                    ERRORS=$((ERRORS + 1))
                fi
            fi
        fi
    done

    if [ "$ERRORS" = 0 ]; then
        ok "All home directories have correct ownership"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Modifying home directories may seriously harm your system, report only here"
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
