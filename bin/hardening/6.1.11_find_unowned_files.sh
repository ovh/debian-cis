#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.1.11 Ensure no unowned files or directories exist (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure no unowned files or directories exist."

USER='root'
EXCLUDED=''

# find emits following error if directory or file disappear during
# tree traversal: find: ‘/tmp/xxx’: No such file or directory
FIND_IGNORE_NOSUCHFILE_ERR=false

# This function will be called if the script status is on enabled / audit mode
audit() {
    info "Checking if there are unowned files"
    if [ -n "$EXCLUDED" ]; then
        # maybe EXCLUDED allow us to filter out some FS
        FS_NAMES=$(df --local -P | awk '{if (NR!=1) print $6}' | grep -vE "$EXCLUDED")

        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set +e
        # shellcheck disable=SC2086
        RESULT=$($SUDO_CMD find $FS_NAMES -xdev -ignore_readdir_race -nouser -regextype 'egrep' ! -regex $EXCLUDED -print 2>/dev/null)
        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set -e
    else
        FS_NAMES=$(df --local -P | awk '{if (NR!=1) print $6}')

        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set +e
        # shellcheck disable=SC2086
        RESULT=$($SUDO_CMD find $FS_NAMES -xdev -ignore_readdir_race -nouser -print 2>/dev/null)
        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set -e
    fi

    if [ -n "$RESULT" ]; then
        crit "Some unowned files are present"
        # shellcheck disable=SC2001
        FORMATTED_RESULT=$(sed "s/ /\n/g" <<<"$RESULT" | sort | uniq | tr '\n' ' ')
        crit "$FORMATTED_RESULT"
    else
        ok "No unowned files found"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ -n "$EXCLUDED" ]; then
        # shellcheck disable=SC2086
        RESULT=$(df --local -P | awk '{if (NR!=1) print $6}' | grep -vE "$EXCLUDED" | xargs -I '{}' find '{}' -xdev -ignore_readdir_race -nouser -regextype 'egrep' ! -regex "$EXCLUDED" -ls 2>/dev/null)
    else
        RESULT=$(df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -ignore_readdir_race -nouser -ls 2>/dev/null)
    fi
    if [ -n "$RESULT" ]; then
        warn "Applying chown on all unowned files in the system"
        df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -ignore_readdir_race -nouser -print 2>/dev/null | xargs chown "$USER"
    else
        ok "No unowned files found, nothing to apply"
    fi
}

# This function will check config parameters required
check_config() {
    # No param for this function
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
