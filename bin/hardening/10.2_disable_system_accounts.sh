#!/bin/bash

#
# CIS Debian Hardening
#

#
# 10.2 Disable System Accounts (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3
DESCRIPTION="Disable system accounts, preventing them from interactive login."

SHELL='/bin/false'
FILE='/etc/passwd'
RESULT=''

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if admin accounts have a login shell different than $SHELL"
    RESULT=$(egrep -v "^\+" $FILE | awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $3<1000 && $7!="/usr/sbin/nologin" && $7!="/bin/false") {print}')
    IFS=$'\n'
    for LINE in $RESULT; do
        debug "line : $LINE"
        ACCOUNT=$( echo $LINE | cut -d: -f 1 )
        debug "Account : $ACCOUNT"
        debug "Exceptions : $EXCEPTIONS"
        debug "echo \"$EXCEPTIONS\" | grep -q $ACCOUNT"
        if echo "$EXCEPTIONS" | grep -q $ACCOUNT; then
            debug "$ACCOUNT is confirmed as an exception"
            RESULT=$(sed "s!$LINE!!" <<< "$RESULT")
        else
            debug "$ACCOUNT not found in exceptions"
        fi
    done
    if [ ! -z "$RESULT" ]; then
        crit "Some admin accounts don't have $SHELL as their login shell"
        crit "$RESULT"
    else
        ok "All admin accounts deactivated"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    RESULT=$(egrep -v "^\+" $FILE | awk -F: '($1!="root" && $1!="sync" && $1!="shutdown" && $1!="halt" && $3<1000 && $7!="/usr/sbin/nologin" && $7!="/bin/false") {print}')
    IFS=$'\n'
    for LINE in $RESULT; do
        debug "line : $LINE"
        ACCOUNT=$( echo $LINE | cut -d: -f 1 )
        debug "Account : $ACCOUNT"
        debug "Exceptions : $EXCEPTIONS"
        debug "echo \"$EXCEPTIONS\" | grep -q $ACCOUNT"
        if echo "$EXCEPTIONS" | grep -q $ACCOUNT; then
            debug "$ACCOUNT is confirmed as an exception"
            RESULT=$(sed "s!$LINE!!" <<< "$RESULT")
        else
            debug "$ACCOUNT not found in exceptions"
        fi
    done
    if [ ! -z "$RESULT" ]; then
        warn "Some admin accounts don't have $SHELL as their login shell -- Fixing"
        warn "$RESULT"
        for USER in $( echo "$RESULT" | cut -d: -f 1 ); do
            info "Setting $SHELL as $USER login shell"
            usermod -s $SHELL $USER
        done
    else
        ok "All admin accounts deactivated, nothing to apply"
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put here your exceptions concerning admin accounts shells separated by spaces
EXCEPTIONS=""
EOF
}

# This function will check config parameters required
check_config() {
    if [ -z "$EXCEPTIONS" ]; then
        EXCEPTIONS="@"
    fi
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
     echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
     echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r $CIS_ROOT_DIR/lib/main.sh ]; then
    . $CIS_ROOT_DIR/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
