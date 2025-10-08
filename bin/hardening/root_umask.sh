#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure root user umask is configured (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Set default mask for root to 027."
UMASK_VALUE=""

# This function will be called if the script status is on enabled / audit mode
audit() {
    ROOT_UMASK_VALID=1
    # order of precedence, from strongest to weakest
    # /root/.bash_profile
    # /root/.bashrc
    # The system default umask
    local UMASK_PROFILE_VALUE=""
    does_file_exist /root/.bash_profile
    if [ "$FNRET" -eq 0 ]; then
        UMASK_PROFILE_VALUE=$($SUDO_CMD grep -E "^[^#]*umask" /root/.bash_profile | awk '{print $2}')
    fi

    local UMASK_BASHRC_VALUE=""
    does_file_exist /root/.bashrc
    if [ "$FNRET" -eq 0 ]; then
        UMASK_BASHRC_VALUE=$($SUDO_CMD grep -E "^[^#]*umask" /root/.bashrc | awk '{print $2}')
    fi

    if [ -n "$UMASK_PROFILE_VALUE" ]; then
        if [ "$UMASK_PROFILE_VALUE" -ne "$UMASK_VALUE" ]; then
            crit "root umask is $UMASK_PROFILE_VALUE instead of $UMASK_VALUE"
        else
            ok "root umask is $UMASK_PROFILE_VALUE"
            ROOT_UMASK_VALID=0
        fi
    elif [ -n "$UMASK_BASHRC_VALUE" ]; then
        if [ "$UMASK_BASHRC_VALUE" -ne "$UMASK_VALUE" ]; then
            crit "root umask is $UMASK_BASHRC_VALUE instead of $UMASK_VALUE"
        else
            ok "root umask is $UMASK_BASHRC_VALUE"
            ROOT_UMASK_VALID=0
        fi
    else
        crit "There is no specific umask for root"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$ROOT_UMASK_VALID" -ne 0 ]; then
        # remove eventual current entries
        does_file_exist /root/.bashrc
        if [ "$FNRET" -eq 0 ]; then
            sed -i '/umask/d' /root/.bash_profile
        fi
        echo "umask $UMASK_VALUE" >>/root/.bash_profile
    fi
}

create_config() {
    cat <<EOF
# shellcheck disable=2034
status=audit
UMASK_VALUE='027'
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
