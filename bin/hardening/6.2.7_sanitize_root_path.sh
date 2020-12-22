#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.2.7 Ensure root PATH Integrity (Scored)
#

# set path to the $PATH environnement variable if path is not defined
# used in test
[[ $path && ${path-x} ]] || path=$PATH

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure root path integrity."

ERRORS=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    if [ "$(echo "$path" | grep ::)" != "" ]; then
        crit "Empty Directory in PATH (::)"
        ERRORS=$((ERRORS + 1))
    fi
    if [ "$(echo "$path" | grep :$)" != "" ]; then
        crit "Trailing : in PATH $path"
        ERRORS=$((ERRORS + 1))
    fi
    FORMATTED_PATH=$(echo "$path" | sed -e 's/::/:/' -e 's/:$//' -e 's/:/ /g')
    # shellcheck disable=SC2086
    set -- $FORMATTED_PATH
    while [ "${1:-}" != "" ]; do
        if [ "$1" = "." ]; then
            crit "PATH contains ."
            ERRORS=$((ERRORS + 1))
        else
            if [ -d "$1" ]; then
                dirperm=$(stat -L -c "%A" "$1")
                dirown=$(stat -c "%U" "$1")
                if [ "$(echo "$dirperm" | cut -c6)" != "-" ]; then
                    crit "Group Write permission set on directory $1"
                    ERRORS=$((ERRORS + 1))
                fi
                if [ "$(echo "$dirperm" | cut -c9)" != "-" ]; then
                    crit "Other Write permission set on directory $1"
                    ERRORS=$((ERRORS + 1))
                fi
                if [ "$dirown" != "root" ]; then
                    crit "$1 is not owned by root"
                    ERRORS=$((ERRORS + 1))
                fi
            else
                crit "$1 is not a directory"
                ERRORS=$((ERRORS + 1))
            fi
        fi
        shift
    done

    if [ "$ERRORS" = 0 ]; then
        ok "root PATH is secure"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Editing items from PATH may seriously harm your system, report only here"
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
