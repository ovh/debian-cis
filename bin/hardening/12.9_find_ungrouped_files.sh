#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 12.9 Find Un-grouped Files and Directories (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=2
DESCRIPTION="Find un-grouped files and directories."

GROUP='root'

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Checking if there are ungrouped files"
    RESULT=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' $SUDO_CMD find '{}' -xdev -nogroup -print 2>/dev/null)
    if [ ! -z "$RESULT" ]; then
        crit "Some ungrouped files are present"
        FORMATTED_RESULT=$(sed "s/ /\n/g" <<< $RESULT | sort | uniq | tr '\n' ' ')
        crit "$FORMATTED_RESULT"
    else
        ok "No ungrouped files found"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    RESULT=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -nogroup -ls 2>/dev/null)
    if [ ! -z "$RESULT" ]; then
        warn "Applying chgrp on all ungrouped files in the system"
        df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -nogroup -print 2>/dev/null | xargs chgrp $GROUP
    else
        ok "No ungrouped files found, nothing to apply"
    fi
}

# This function will check config parameters required
check_config() {
    # No param for this function
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
