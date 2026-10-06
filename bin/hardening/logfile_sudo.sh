#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure sudo log file exists (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Ensure sudo log files exists."

PATTERN="^\s*Defaults\s+logfile=\S+"
LOGFILE="/var/log/sudo.log"
SUDO_LOGFILE_DROPIN="/etc/sudoers.d/cis_sudo_logfile"

# 0 = found / compliant, 1 = not found
SUDO_LOGFILE_FOUND=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    SUDO_LOGFILE_FOUND=1
    for f in /etc/{sudoers,sudoers.d/*}; do
        does_pattern_exist_in_file_nocase "$f" "$PATTERN"
        if [ "$FNRET" = 0 ]; then
            SUDO_LOGFILE_FOUND=0
        fi
    done

    if [ "$SUDO_LOGFILE_FOUND" = 0 ]; then
        ok "Defaults log file found in sudoers file"
    else
        crit "Defaults log file not found in sudoers files"
    fi
}
# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SUDO_LOGFILE_FOUND" = 0 ]; then
        ok "Defaults log file found in sudoers file"
    else
        warn "Defaults log file not found in sudoers files, fixing"
        local l_tmpfile
        l_tmpfile=$(mktemp)
        echo "Defaults        logfile=\"$LOGFILE\"" >"$l_tmpfile"
        if visudo -c -f "$l_tmpfile" >/dev/null 2>&1; then
            install -m 0440 -o root -g root "$l_tmpfile" "$SUDO_LOGFILE_DROPIN"
            ok "Created $SUDO_LOGFILE_DROPIN"
        else
            crit "Generated sudoers snippet failed validation, not installing"
        fi
        rm -f "$l_tmpfile"
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
