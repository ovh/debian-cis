#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 8.3.2 Implement Periodic Execution of File Integrity (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=4
# shellcheck disable=2034
DESCRIPTION="Implemet periodic execution of file integrity."

FILES="/etc/crontab $(find /etc/cron.d/ -type f)"
PATTERN='tripwire --check'

# This function will be called if the script status is on enabled / audit mode
audit () {
    FOUND=0
    for FILE in $FILES; do
        does_pattern_exist_in_file "$FILE" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            FOUND=1
        fi
    done
    if [ $FOUND = 1 ]; then
        ok "$PATTERN is present in $FILES"
    else
        crit "$PATTERN is not present in $FILES"
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    does_pattern_exist_in_file "$FILES" "$PATTERN"
    if [ "$FNRET" != 0 ]; then
        warn "$PATTERN is not present in $FILES, setting tripwire cron"
        echo "0 10 * * * root /usr/sbin/tripwire --check > /dev/shm/tripwire_check 2>&1 " > /etc/cron.d/CIS_8.3.2_tripwire
    else
        ok "$PATTERN is present in $FILES"
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
if [ -r "$CIS_ROOT_DIR"/lib/main.sh ]; then
    # shellcheck source=/opt/debian-cis/lib/main.sh
    . "$CIS_ROOT_DIR"/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
