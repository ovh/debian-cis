#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure password hashing algorithm is SHA-512 (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Check that the algorithm declared in PAM for password changes is sha512 (or yescrypt for Debian 11+)"

CONF_FILE="/etc/pam.d/common-password"
# CONF_LINE is defined in _set_vars_jit below

# This function will be called if the script status is on enabled / audit mode
audit() {
    _set_vars_jit
    # Check conf file for default SHA512 hash
    if $SUDO_CMD [ ! -r "$CONF_FILE" ]; then
        crit "$CONF_FILE is not readable"
    else
        # shellcheck disable=SC2001
        does_pattern_exist_in_file "$CONF_FILE" "$(sed 's/ /[[:space:]]+/g' <<<"$CONF_LINE")"
        if [ "$FNRET" = 0 ]; then
            ok "$CONF_LINE is present in $CONF_FILE"
        else
            crit "$CONF_LINE is not present in $CONF_FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    _set_vars_jit
    if $SUDO_CMD [ ! -r "$CONF_FILE" ]; then
        crit "$CONF_FILE is not readable"
    else
        # shellcheck disable=SC2001
        does_pattern_exist_in_file "$CONF_FILE" "$(sed 's/ /[[:space:]]+/g' <<<"$CONF_LINE")"
        if [ "$FNRET" = 0 ]; then
            ok "$CONF_LINE is present in $CONF_FILE"
        else
            warn "$CONF_LINE is not present in $CONF_FILE"
            if [ "$DEB_MAJ_VER" = "sid" ] || [ "$DEB_MAJ_VER" -ge "11" ]; then
                add_line_file_before_pattern "$CONF_FILE" "password [success=1 default=ignore] pam_unix.so yescrypt" "# pam-auth-update(8) for details."
            else
                add_line_file_before_pattern "$CONF_FILE" "password [success=1 default=ignore] pam_unix.so sha512" "# pam-auth-update(8) for details."
            fi
        fi
    fi
}

# This function will check config parameters required
check_config() {
    :
}

# As we use DEB_MAJ_VER, which is set by constants.sh, itself sourced by main.sh below,
# We need to call this in the subs called by main.sh when it is sourced, otherwise it would
# either be too soon (DEB_MAJ_VER not defined) or too late (test has already been run)
_set_vars_jit() {
    if [ "$DEB_MAJ_VER" = "sid" ] || [ "$DEB_MAJ_VER" -ge "11" ]; then
        CONF_LINE="^\s*password\s.+\s+pam_unix\.so\s+.*(sha512|yescrypt)" # https://github.com/ovh/debian-cis/issues/158
    else
        CONF_LINE="^\s*password\s.+\s+pam_unix\.so\s+.*sha512"
    fi
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
