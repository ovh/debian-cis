#!/bin/bash

#
# CIS Debian 7 Hardening
#

#
# 8.2.3 Configure /etc/syslog-ng/syslog-ng.conf (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

SERVICE_NAME="syslog-ng"

# This function will be called if the script status is on enabled / audit mode
audit () {
    info "Ensure default and local facilities are preserved on the system"
    info "No measure here, please review the file by yourself"
}

# This function will be called if the script status is on enabled mode
apply () {
    info "Ensure default and local facilities are preserved on the system"
    info "No measure here, please review the file by yourself"
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
