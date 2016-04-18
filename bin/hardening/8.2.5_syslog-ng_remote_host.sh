#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 8.2.5 Configure rsyslog to Send Logs to a Remote Log Host (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

PATTERN='^destination.*(tcp|udp)[[:space:]]*\([[:space:]]*\".*\"[[:space:]]*\)'

# This function will be called if the script status is on enabled / audit mode
audit () {
    FILES="$SYSLOG_BASEDIR/syslog-ng.conf $SYSLOG_BASEDIR/conf.d/*"
    does_pattern_exists_in_file "$FILES" "$PATTERN"
    if [ $FNRET != 0 ]; then
        crit "$PATTERN not present in $FILES"
    else
        ok "$PATTERN present in $FILES"
    fi 
}

# This function will be called if the script status is on enabled mode
apply () {
    FILES="$SYSLOG_BASEDIR/syslog-ng.conf $SYSLOG_BASEDIR/conf.d/*"
    does_pattern_exists_in_file "$FILES" "$PATTERN"
    if [ $FNRET != 0 ]; then
        crit "$PATTERN not present in $FILES, please set a remote host to send your logs"
    else
        ok "$PATTERN present in $FILES"
    fi
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
