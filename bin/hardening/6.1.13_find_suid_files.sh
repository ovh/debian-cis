#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 6.1.13 Audit SUID executables (Not Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Find SUID system executables."
IGNORED_PATH=''

# find emits following error if directory or file disappear during
# tree traversal: find: ‘/tmp/xxx’: No such file or directory
FIND_IGNORE_NOSUCHFILE_ERR=false

# This function will be called if the script status is on enabled / audit mode
audit() {
    info "Checking if there are suid files"
    if [ -n "$IGNORED_PATH" ]; then
        # maybe IGNORED_PATH allow us to filter out some FS
        FS_NAMES=$(df --local -P | awk '{if (NR!=1) print $6}' | grep -vE "$IGNORED_PATH")

        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set +e
        # shellcheck disable=2086
        FOUND_BINARIES=$($SUDO_CMD find $FS_NAMES -xdev -ignore_readdir_race -type f -perm -4000 -regextype 'egrep' ! -regex $IGNORED_PATH -print)
        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set -e
    else
        FS_NAMES=$(df --local -P | awk '{if (NR!=1) print $6}')

        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set +e
        # shellcheck disable=2086
        FOUND_BINARIES=$($SUDO_CMD find $FS_NAMES -xdev -ignore_readdir_race -type f -perm -4000 -print)
        [ "${FIND_IGNORE_NOSUCHFILE_ERR}" = true ] && set -e
    fi

    BAD_BINARIES=""
    for BINARY in $FOUND_BINARIES; do
        if grep -qw "$BINARY" <<<"$EXCEPTIONS"; then
            debug "$BINARY is confirmed as an exception"
        else
            BAD_BINARIES="$BAD_BINARIES $BINARY"
        fi
    done
    if [ -n "$BAD_BINARIES" ]; then
        crit "Some suid files are present"
        # shellcheck disable=SC2001
        FORMATTED_RESULT=$(sed "s/ /\n/g" <<<"$BAD_BINARIES" | sort | uniq | tr '\n' ' ')
        crit "$FORMATTED_RESULT"
    else
        ok "No unknown suid files found"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "Removing suid on valid binary may seriously harm your system, report only here"
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put Here your valid suid binaries so that they do not appear during the audit
EXCEPTIONS="/bin/mount /usr/bin/mount /bin/ping /usr/bin/ping /bin/ping6 /usr/bin/ping6 /bin/su /usr/bin/su /bin/umount /usr/bin/umount /usr/bin/chfn /usr/bin/chsh /usr/bin/fping /usr/bin/fping6 /usr/bin/gpasswd /usr/bin/mtr /usr/bin/newgrp /usr/bin/passwd /usr/bin/sudo /usr/bin/sudoedit /usr/lib/openssh/ssh-keysign /usr/lib/pt_chown /usr/bin/at"
EOF
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
