#!/bin/bash

# run-shellcheck
#
# Legacy CIS Debian Hardening
#

#
# 99.2.2 Ensure telnet server is not enabled (Scored)
#

# Note: this check is not anymore in CIS hardening but we decided to keep it anyway

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure telnet server is not enabled. Recommended alternative : sshd (OpenSSH-server)."

# Based on  aptitude search '~Ptelnet-server'
PACKAGES='telnetd inetutils-telnetd telnetd-ssl krb5-telnetd heimdal-servers'
FILE='/etc/inetd.conf'
PATTERN='^telnet'

# This function will be called if the script status is on enabled / audit mode
audit() {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" = 0 ]; then
            warn "$PACKAGE is installed, checking configuration"
            does_file_exist "$FILE"
            if [ "$FNRET" != 0 ]; then
                ok "$FILE does not exist"
            else
                does_pattern_exist_in_file "$FILE" "$PATTERN"
                if [ "$FNRET" = 0 ]; then
                    crit "$PATTERN exists, $PACKAGE services are enabled!"
                else
                    ok "$PATTERN is not present in $FILE"
                fi
            fi
        else
            ok "$PACKAGE is absent"
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    for PACKAGE in $PACKAGES; do
        is_pkg_installed "$PACKAGE"
        if [ "$FNRET" = 0 ]; then
            crit "$PACKAGE is installed, purging it"
            apt-get purge "$PACKAGE" -y
            apt-get autoremove
        else
            ok "$PACKAGE is absent"
        fi
        does_file_exist "$FILE"
        if [ "$FNRET" != 0 ]; then
            ok "$FILE does not exist"
        else
            info "$FILE exists, checking patterns"
            does_pattern_exist_in_file "$FILE" "$PATTERN"
            if [ "$FNRET" = 0 ]; then
                warn "$PATTERN is present in $FILE, purging it"
                backup_file $FILE
                # shellcheck disable=SC2001
                ESCAPED_PATTERN=$(sed "s/|\|(\|)/\\\&/g" <<<$PATTERN)
                sed -ie "s/$ESCAPED_PATTERN/#&/g" "$FILE"
            else
                ok "$PATTERN is not present in $FILE"
            fi
        fi
    done
}

# This function will check config parameters required
check_config() {
    :
}

# Source Root Dir Parameter
if [ -r /etc/default/cis-hardening ]; then
    # shellcheck source=../../debian/default
    . /etc/default/cis-hardening
fi
if [ -z "$CIS_ROOT_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_ROOT_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "$CIS_ROOT_DIR"/lib/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "$CIS_ROOT_DIR"/lib/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_ROOT_DIR in /etc/default/cis-hardening"
    exit 128
fi
