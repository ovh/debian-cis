#!/bin/bash

#
# CIS Debian 7/8 Hardening
#

#
# 4.1 Restrict Core Dumps (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

HARDENING_LEVEL=2

LIMIT_FILE='/etc/security/limits.conf'
LIMIT_PATTERN='^\*[[:space:]]*hard[[:space:]]*core[[:space:]]*0$'
SYSCTL_PARAM='fs.suid_dumpable'
SYSCTL_EXP_RESULT=0

# This function will be called if the script status is on enabled / audit mode
audit () {
    does_pattern_exist_in_file $LIMIT_FILE $LIMIT_PATTERN
    if [ $FNRET != 0 ]; then
        crit "$LIMIT_PATTERN not present in $LIMIT_FILE"
    else
        ok "$LIMIT_PATTERN present in $LIMIT_FILE"
    fi
    has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
    if [ $FNRET != 0 ]; then
        crit "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT"
    elif [ $FNRET = 255 ]; then
        warn "$SYSCTL_PARAM does not exist -- Typo?"
    else
        ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    does_pattern_exist_in_file $LIMIT_FILE $LIMIT_PATTERN
    if [ $FNRET != 0 ]; then
        warn "$LIMIT_PATTERN not present in $LIMIT_FILE, adding at the end of  $LIMIT_FILE"
        add_end_of_file $LIMIT_FILE "* hard core 0"
    else
        ok "$LIMIT_PATTERN present in $LIMIT_FILE"
    fi
    has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
    if [ $FNRET != 0 ]; then
        warn "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT -- Fixing"
        set_sysctl_param $SYSCTL_PARAM $SYSCTL_EXP_RESULT
    elif [ $FNRET = 255 ]; then
        warn "$SYSCTL_PARAM does not exist -- Typo?"
    else
        ok "$SYSCTL_PARAM correctly set to $SYSCTL_EXP_RESULT"
    fi 

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
