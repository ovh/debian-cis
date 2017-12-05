#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 6.15 Configure Mail Transfer Agent for Local-Only Mode (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3
HARDENING_EXCEPTION=mail

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking netport ports opened"
    RESULT=$(netstat -an | grep LIST | grep ":25[[:space:]]") || :
    RESULT=${RESULT:-}
    debug "Result is $RESULT"
    if [ -z "$RESULT" ]; then
        ok "Nothing listens on 25 port, probably unix socket configured"
    else
        info "Checking $RESULT"
        if  $(grep -q "127.0.0.1" <<< $RESULT); then
            ok "MTA is configured to localhost only"
        else
            crit "MTA listens worldwide"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Checking netport ports opened"
    RESULT=$(netstat -an | grep LIST | grep ":25[[:space:]]") || :
    RESULT=${RESULT:-}
    debug "Result is $RESULT"
    if [ -z "$RESULT" ]; then
        ok "Nothing listens on 25 port, probably unix socket configured"
    else
        info "Checking $RESULT"
        if  $(grep -q "127.0.0.1" <<< $RESULT); then
            ok "MTA is configured to localhost only"
        else
            warn "MTA listens worldwide, correct this considering your MTA"
        fi
    fi
    :
}

# This function will check config parameters required
check_config() {
    :
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
