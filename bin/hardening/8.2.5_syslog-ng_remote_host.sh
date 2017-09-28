#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 8.2.5 Configure rsyslog to Send Logs to a Remote Log Host (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=3

PATTERN='^destination.*(tcp|udp)[[:space:]]*\([[:space:]]*\".*\"[[:space:]]*\)'

# This function will be called if the script status is on enabled / audit mode
audit () {
    FILES="$SYSLOG_BASEDIR/syslog-ng.conf $SYSLOG_BASEDIR/conf.d/*"
    does_pattern_exist_in_file "$FILES" "$PATTERN"
    if [ $FNRET != 0 ]; then
        crit "$PATTERN is not present in $FILES"
    else
        ok "$PATTERN is present in $FILES"
    fi 
}

# This function will be called if the script status is on enabled mode
apply () {
    FILES="$SYSLOG_BASEDIR/syslog-ng.conf $SYSLOG_BASEDIR/conf.d/*"
    does_pattern_exist_in_file "$FILES" "$PATTERN"
    if [ $FNRET != 0 ]; then
        crit "$PATTERN is not present in $FILES, please set a remote host to send your logs"
    else
        ok "$PATTERN is present in $FILES"
    fi
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=disabled
SYSLOG_BASEDIR='/etc/syslog-ng'
EOF
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
