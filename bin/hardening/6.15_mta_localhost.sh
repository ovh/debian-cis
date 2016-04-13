#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 6.15 Configure Mail Transfer Agent for Local-Only Mode (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking netport ports opened"
    eval 'RESULT=$(netstat -an | grep LIST | grep ":25[[:space:]]")'
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
    eval 'RESULT=$(netstat -an | grep LIST | grep ":25[[:space:]]")'
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
if [ ! -r /etc/default/cis-hardenning ]; then
    echo "There is no /etc/default/cis-hardenning file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardenning
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
