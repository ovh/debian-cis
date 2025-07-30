#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure at is restricted to authorized users (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure at is restricted to authorized users"
PACKAGE="at"

# This function will be called if the script status is on enabled / audit mode
audit() {
    ALLOW_EXISTS=1
    ALLOW_VALID=0
    DENY_EXISTS=1
    DENY_EMPTY=1
    DENY_VALID=0

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" -eq 1 ]; then
        ok "$PACKAGE is not installed"
    else
        does_file_exist "/etc/at.allow"
        if [ "$FNRET" -eq 0 ]; then
            ALLOW_EXISTS=0

            # valid if file:
            # - Exists
            # - Is mode 0640 or more restrictive
            # - Is owned by the user root
            # - Is group owned by the group daemon or group root
            if [ "$(stat -Lc '%U' /etc/at.allow)" != 'root' ]; then
                ALLOW_VALID=1
                crit "'/etc/at.allow' is not owned by root"
            fi

            group="$(stat -Lc '%G' /etc/at.allow)"
            if [ "$group" != 'root' ] && [ "$group" != 'daemon' ]; then
                ALLOW_VALID=1
                crit "'/etc/at.allow' is not owned by group root or group 'daemon'"
            fi

            if [ "$(stat -Lc '%a' /etc/at.allow)" != '640' ]; then
                ALLOW_VALID=1
                crit "'/etc/at.allow' perms is not '640'"
            fi

        fi

        does_file_exist "/etc/at.deny"
        if [ "$FNRET" -eq 0 ]; then
            DENY_EXISTS=0
            is_file_empty "/etc/at.deny"
            if [ "$FNRET" -eq 0 ]; then
                DENY_EMPTY=0
            fi

            if [ "$(stat -Lc '%U' /etc/at.deny)" != 'root' ]; then
                DENY_VALID=1
                crit "'/etc/at.deny' is not owned by root"
            fi

            group="$(stat -Lc '%G' /etc/at.deny)"
            if [ "$group" != 'root' ] && [ "$group" != 'daemon' ]; then
                DENY_VALID=1
                crit "'/etc/at.deny' is not owned by group 'root' or group 'daemon'"
            fi

            if [ "$(stat -Lc '%a' /etc/at.deny)" != '640' ]; then
                DENY_VALID=1
                crit "'/etc/at.deny' perms is not '640'"
            fi

        fi

        # If neither /etc/at.allow and /etc/at.deny exist, only the superuser is allowed to use at.
        if [ "$ALLOW_EXISTS" -eq 1 ] && [ "$DENY_EXISTS" -eq 1 ]; then
            ok "only superuser is allowed to run 'at' commands"

        # If /etc/at.allow does not exist, /etc/at.deny is checked, every username not mentioned in it is then allowed to use at.
        # An empty /etc/at.deny means that every user may use at.
        elif [ "$ALLOW_EXISTS" -eq 1 ] && [ "$DENY_EXISTS" -eq 0 ]; then
            if [ "$DENY_EMPTY" -eq 0 ]; then
                crit "all users are allowed to execute 'at' commands"
            elif [ "$DENY_VALID" -eq 1 ]; then
                crit "'/etc/at.deny' exists but is misconfigured"
            else
                ok "'/etc/at.deny' exists and is correctly configured"
            fi
        fi

        # If the file /etc/at.allow exists, only usernames mentioned in it are allowed to use at.
        if [ "$ALLOW_EXISTS" -eq 0 ] && [ "$ALLOW_VALID" -eq 1 ]; then
            crit "'/etc/at.allow' exists but is misconfigured"
        elif [ "$ALLOW_EXISTS" -eq 0 ] && [ "$ALLOW_VALID" -eq 0 ]; then
            ok "'/etc/at.allow' exists and is well configured"
        fi

    fi

}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$ALLOW_EXISTS" -eq 1 ] && [ "$DENY_EXISTS" -eq 0 ]; then
        if [ "$DENY_EMPTY" -eq 0 ]; then
            info "Removing '/etc/at.deny'"
            rm -f /etc/at.deny
        elif [ "$DENY_VALID" -eq 1 ]; then
            info "set perms and owner on '/etc/at.deny'"
            chmod 0640 /etc/at.deny
            chown root /etc/at.deny
            if [ "$(stat -Lc '%G' /etc/at.deny)" != "daemon" ]; then
                chgrp root /etc/at.deny
            fi
        fi
    fi

    if [ "$ALLOW_EXISTS" -eq 0 ] && [ "$ALLOW_VALID" -eq 1 ]; then
        info "set perms and owner on '/etc/at.allow'"
        chmod 0640 /etc/at.allow
        chown root /etc/at.allow
        if [ "$(stat -Lc '%G' /etc/at.allow)" != "daemon" ]; then
            chgrp root /etc/at.allow
        fi
    fi

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
