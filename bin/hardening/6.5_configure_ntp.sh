#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 6.5 Configure Network Time Protocol (NTP) (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

PACKAGE='ntp'
NTP_CONF_DEFAULT_PATTERN='^restrict -4 default (kod nomodify notrap nopeer noquery|ignore)'
NTP_CONF_FILE='/etc/ntp.conf'
NTP_INIT_PATTERN='RUNASUSER=ntp'
NTP_INIT_FILE='/etc/init.d/ntp'

# This function will be called if the script status is on enabled / audit mode
audit () {
    is_pkg_installed $PACKAGE
    if [ $FNRET != 0 ]; then
        crit "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed, checking configuration"
        does_pattern_exists_in_file $NTP_CONF_FILE $NTP_CONF_DEFAULT_PATTERN
        if [ $FNRET != 0 ]; then
            crit "$NTP_CONF_DEFAULT_PATTERN not found in $NTP_CONF_FILE"
        else
            ok "$NTP_CONF_DEFAULT_PATTERN found in $NTP_CONF_FILE"
        fi
        does_pattern_exists_in_file $NTP_INIT_FILE "^$NTP_INIT_PATTERN"
        if [ $FNRET != 0 ]; then
            crit "$NTP_INIT_PATTERN not found in $NTP_INIT_FILE"
        else
            ok "$NTP_INIT_PATTERN found in $NTP_INIT_FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
        is_pkg_installed $PACKAGE
        if [ $FNRET = 0 ]; then
            ok "$PACKAGE is installed"
        else
            crit "$PACKAGE is absent, installing it"
            apt_install $PACKAGE
            info "Checking $PACKAGE configuration"
        fi
        does_pattern_exists_in_file $NTP_CONF_FILE $NTP_CONF_DEFAULT_PATTERN
        if [ $FNRET != 0 ]; then
            warn "$NTP_CONF_DEFAULT_PATTERN not found in $NTP_CONF_FILE, adding it"
            backup_file $NTP_CONF_FILE
            add_end_of_file $NTP_CONF_FILE "restrict -4 default kod notrap nomodify nopeer noquery"
        else
            ok "$NTP_CONF_DEFAULT_PATTERN found in $NTP_CONF_FILE"
        fi
        does_pattern_exists_in_file $NTP_INIT_FILE "^$NTP_INIT_PATTERN"
        if [ $FNRET != 0 ]; then
            warn "$NTP_INIT_PATTERN not found in $NTP_INIT_FILE, adding it"
            backup_file $NTP_INIT_FILE
            add_line_file_before_pattern $NTP_INIT_FILE $NTP_INIT_PATTERN "^UGID" 
        else
            ok "$NTP_INIT_PATTERN found in $NTP_INIT_FILE"
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
