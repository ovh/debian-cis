#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure no world writable files or directories exist (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure no world writable files or directories exist"

EXCLUDED=''

# find emits following error if directory or file disappear during
# tree traversal: find: '/tmp/xxx': No such file or directory
FIND_IGNORE_NOSUCHFILE_ERR=false

WORLD_WRITABLE_FILES_RESULT=''
WORLD_WRITABLE_DIRS_RESULT=''

# This function will be called if the script status is on enabled / audit mode
audit() {
    info "Checking if there are world writable files or directories"
    if [ -n "$EXCLUDED" ]; then
        # maybe EXCLUDED allow us to filter out some FS
        FS_NAMES=$(df --local -P | awk '{if (NR!=1) print $6}' | grep -vE "$EXCLUDED")

        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set +e
        # shellcheck disable=SC2086
        WORLD_WRITABLE_FILES_RESULT=$($SUDO_CMD find $FS_NAMES -xdev -ignore_readdir_race -type f -perm -0002 -regextype 'egrep' ! -regex $EXCLUDED -print 2>/dev/null)
        # shellcheck disable=SC2086
        WORLD_WRITABLE_DIRS_RESULT=$($SUDO_CMD find $FS_NAMES -xdev -ignore_readdir_race -type d \( -perm -0002 -a ! -perm -1000 \) -regextype 'egrep' ! -regex $EXCLUDED -print 2>/dev/null)
        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set -e
    else
        FS_NAMES=$(df --local -P | awk '{if (NR!=1) print $6}')

        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set +e
        # shellcheck disable=SC2086
        WORLD_WRITABLE_FILES_RESULT=$($SUDO_CMD find $FS_NAMES -xdev -ignore_readdir_race -type f -perm -0002 -print 2>/dev/null)
        # shellcheck disable=SC2086
        WORLD_WRITABLE_DIRS_RESULT=$($SUDO_CMD find $FS_NAMES -xdev -ignore_readdir_race -type d \( -perm -0002 -a ! -perm -1000 \) -print 2>/dev/null)
        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set -e
    fi

    if [ -n "$WORLD_WRITABLE_FILES_RESULT" ] || [ -n "$WORLD_WRITABLE_DIRS_RESULT" ]; then
        crit "Some world writable files or directories are present"
        if [ -n "$WORLD_WRITABLE_FILES_RESULT" ]; then
            crit "Some world writable files are present"
        fi
        if [ -n "$WORLD_WRITABLE_DIRS_RESULT" ]; then
            crit "Some world writable directories are not on sticky bit mode"
        fi
        # shellcheck disable=SC2001
        FORMATTED_RESULT=$(printf '%s\n%s\n' "$WORLD_WRITABLE_FILES_RESULT" "$WORLD_WRITABLE_DIRS_RESULT" | sed '/^$/d' | sed "s/ /\n/g" | sort | uniq | tr '\n' ' ')
        crit "$FORMATTED_RESULT"
    else
        ok "No world writable files or directories requiring remediation found"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ -n "$WORLD_WRITABLE_FILES_RESULT" ]; then
        warn "chmoding o-w all world writable files in the system"
        printf '%s\n' "$WORLD_WRITABLE_FILES_RESULT" | sed '/^$/d' | xargs chmod o-w
    fi

    if [ -n "$WORLD_WRITABLE_DIRS_RESULT" ]; then
        warn "Setting sticky bit on world writable directories"
        printf '%s\n' "$WORLD_WRITABLE_DIRS_RESULT" | sed '/^$/d' | xargs chmod a+t
    fi

    if [ -n "$WORLD_WRITABLE_FILES_RESULT" ] || [ -n "$WORLD_WRITABLE_DIRS_RESULT" ]; then
        ok "World writable files and directories remediation applied"
    else
        ok "No world writable files or directories requiring remediation found, nothing to apply"
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
