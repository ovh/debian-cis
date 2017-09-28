#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 13.5 Verify No UID 0 Accounts Exist Other Than root (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=2

FILE='/etc/passwd'
RESULT=''

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if accounts have uid 0"
    RESULT=$(cat $FILE | awk -F: '($3 == 0 && $1!="root" ) { print $1 }')
    for ACCOUNT in $RESULT; do
        debug "Account : $ACCOUNT"
        debug "Exceptions : $EXCEPTIONS"
        debug "echo \"$EXCEPTIONS\" | grep -q $ACCOUNT"
        if echo "$EXCEPTIONS" | grep -q $ACCOUNT; then
            debug "$ACCOUNT is confirmed as an exception"
            RESULT=$(sed "s!$ACCOUNT!!" <<< "$RESULT")
        else
            debug "$ACCOUNT not found in exceptions"
        fi
    done
    if [ ! -z "$RESULT" ]; then
        crit "Some accounts have uid 0"
        crit $RESULT
    else
        ok "No account with uid 0 appart from root and potential configured exceptions"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Removing accounts with uid 0 may seriously harm your system, report only here"
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=disabled
# Put here valid accounts with uid 0 separated by spaces
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
if [ ! -r /etc/default/cis-hardening ]; then
    echo "There is no /etc/default/cis-hardening file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardening
    if [ -z ${CIS_ROOT_DIR:-} ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
        exit 128
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r $CIS_ROOT_DIR/lib/main.sh ]; then
    . $CIS_ROOT_DIR/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
