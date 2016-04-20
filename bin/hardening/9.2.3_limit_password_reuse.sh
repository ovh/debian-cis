#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 9.2.3 Limit Password Reuse (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

PACKAGE='libpam-modules'
PATTERN='^password.*remember'
FILE='/etc/pam.d/common-password'

# This function will be called if the script status is on enabled / audit mode
audit () {
    is_pkg_installed $PACKAGE
    if [ $FNRET != 0 ]; then
        crit "$PACKAGE is not installed !"
    else
        ok "$PACKAGE is installed"
        does_pattern_exists_in_file $FILE $PATTERN
        if [ $FNRET = 0 ]; then
            ok "$PATTERN is present in $FILE"
        else
            crit "$PATTERN is not present in $FILE"
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
    fi
    does_pattern_exists_in_file $FILE $PATTERN
    if [ $FNRET = 0 ]; then
        ok "$PATTERN is present in $FILE"
    else
        warn "$PATTERN is not present in $FILE"
        add_line_file_before_pattern $FILE "password [success=1 default=ignore] pam_unix.so obscure sha512 remember=5" "# pam-auth-update(8) for details."
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
