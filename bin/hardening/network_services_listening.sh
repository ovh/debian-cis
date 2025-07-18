#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure only approved services are listening on a network interface (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure only approved services are listening on a network interface"
# socket
# ex: "127.0.0.1:123 0.0.0.0:123"
# we only care about the socket, as there may be different process for a same service
# ex: ntp or chrony for time synchronization
EXCEPTIONS=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    # shellcheck disable=2162
    while read i; do
        # sed [] in case of some ipv6 usage
        # ex: [::]:22
        socket=$(echo "$i" | awk '{print $5}' | sed -e 's/\[/\\[/' -e 's/\]/\\]/')
        proc=$(echo "$i" | awk '{print $7}' | awk -F ',' '{print $1}' | sed 's/users:((//')
        if [ -n "$socket" ]; then
            info -e "$proc listening on \t$socket"

            # output example :
            # "ntpd" listening on 	127.0.0.1:123
            # "ntpd" listening on 	0.0.0.0:123

            if grep -w "$socket" <<<"$EXCEPTIONS" >/dev/null; then
                debug "$socket" is an exception
            else
                crit "$socket" is not an exception
            fi
        fi

    done <<<"$($SUDO_CMD ss -plntuH)"

}

# This function will be called if the script status is on enabled mode
apply() {
    info "This recommendation has to be reviewed and applied manually"
}

create_config() {
    # we try to put as default all services that should be running according to the CIS recommendation
    cat <<EOF
status=audit
# Put your custom configuration here
EXCEPTIONS="0.0.0.0:22 [::]:22 0.0.0.0:123 [::]:123"
EOF
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
if [ -z "$CIS_LIB_DIR" ]; then
    echo "There is no /etc/default/cis-hardening file nor cis-hardening directory in current environment."
    echo "Cannot source CIS_LIB_DIR variable, aborting."
    exit 128
fi

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
if [ -r "${CIS_LIB_DIR}"/main.sh ]; then
    # shellcheck source=../../lib/main.sh
    . "${CIS_LIB_DIR}"/main.sh
else
    echo "Cannot find main.sh, have you correctly defined your root directory? Current value is $CIS_LIB_DIR in /etc/default/cis-hardening"
    exit 128
fi
