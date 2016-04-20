#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 8.3.2 Implement Periodic Execution of File Integrity (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

FILES='/etc/crontab /etc/cron.d/*'
PATTERN='tripwire --check'

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_pattern_exists_in_file "$FILES" "$PATTERN"
    if [ $FNRET != 0 ]; then
        crit "$PATTERN not present in $FILES"
    else
        ok "$PATTERN present in $FILES"
    fi 
}

# This function will be called if the script status is on enabled mode
apply () {
    does_pattern_exists_in_file "$FILES" "$PATTERN"
    if [ $FNRET != 0 ]; then
        warn "$PATTERN not present in $FILES, setting tripwire cron"
        echo "0 10 * * * root /usr/sbin/tripwire --check > /dev/shm/tripwire_check 2>&1 " > /etc/cron.d/CIS_8.3.2_tripwire        
    else
        ok "$PATTERN present in $FILES"
    fi
}

# This function will check config parameters required
check_config() {
    :    
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardening ]; then
    echo "There is no /etc/default/cis-hardening file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardening
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
        exit 128
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
