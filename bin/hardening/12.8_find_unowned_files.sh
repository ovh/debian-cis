#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 12.8 Find Un-owned Files and Directories (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

USER='root'

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if there are unowned files"
    RESULT=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -nouser -print 2>/dev/null)
    if [ ! -z "$RESULT" ]; then
        crit "Some unowned files are present"
        FORMATTED_RESULT=$(sed "s/ /\n/g" <<< $RESULT | sort | uniq | tr '\n' ' ')
        crit "$FORMATTED_RESULT"
    else
        ok "No unowned files found"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    RESULT=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -nouser -ls 2>/dev/null)
    if [ ! -z "$RESULT" ]; then
        warn "Applying chown on all unowned files in the system"
        df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -nouser -print 2>/dev/null | xargs chown $USER
    else
        ok "No unowned files found, nothing to apply"
    fi
}

# This function will check config parameters required
check_config() {
    # No param for this function
    :
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
