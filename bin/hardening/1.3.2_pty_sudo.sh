#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# 1.3.2 Ensure sudo commands use pty (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure sudo can only be run from a pseudo pty."

PATTERN='^\s*Defaults\s+([^#]+,\s*)?use_pty(,\s+\S+\s*)*(\s+#.*)?$'

# This function will be called if the script status is on enabled / audit mode
audit() {
    FOUND=0
    for f in /etc/{sudoers,sudoers.d/*}; do
        does_pattern_exist_in_file_nocase "$f" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            FOUND=1
        fi
    done

    if [[ "$FOUND" = 1 ]]; then
        ok "Defaults use_pty found in sudoers file"
    else
        crit "Defaults use_pty not found in sudoers files"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    FOUND=0
    for f in /etc/{sudoers,sudoers.d/*}; do
        does_pattern_exist_in_file_nocase "$f" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            FOUND=1
        fi
    done

    if [[ "$FOUND" = 1 ]]; then
        ok "Defaults use_pty found in sudoers file"
    else
        warn "Defaults use_pty not found in sudoers files, fixing"
        add_line_file_before_pattern /etc/sudoers "Defaults        use_pty" "# Host alias specification"
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
