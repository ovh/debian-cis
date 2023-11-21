#!/bin/bash

# run-shellcheck
#
# OVH Security audit
#

#
# 99.5.4.5.1 Check that any password that will be created will use sha512crypt (or yescrypt for Debian 11+)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Check that any password that will be created will use sha512crypt (or yescrypt for Debian 11+)"

CONF_FILE="/etc/login.defs"
# CONF_LINE and CONF_LINE_REGEX are defined in _set_vars_jit below

# This function will be called if the script status is on enabled / audit mode
audit() {
    _set_vars_jit
    # Check conf file for default SHA512 hash
    if $SUDO_CMD [ ! -r "$CONF_FILE" ]; then
        crit "$CONF_FILE is not readable"
    else
        does_pattern_exist_in_file "$CONF_FILE" "^ *${CONF_LINE_REGEX/ /[[:space:]]+}"
        if [ "$FNRET" = 0 ]; then
            ok "$CONF_LINE_REGEX is present in $CONF_FILE"
        else
            crit "$CONF_LINE_REGEX is not present in $CONF_FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    _set_vars_jit
    does_pattern_exist_in_file "$CONF_FILE" "^ *${CONF_LINE_REGEX/ /[[:space:]]+}"
    if [ "$FNRET" = 0 ]; then
        ok "$CONF_LINE_REGEX is present in $CONF_FILE"
    else
        warn "$CONF_LINE is not present in $CONF_FILE, adding it"
        does_pattern_exist_in_file "$CONF_FILE" "^$(echo "$CONF_LINE" | cut -d ' ' -f1)"
        if [ "$FNRET" != 0 ]; then
            add_end_of_file "$CONF_FILE" "$CONF_LINE"
        else
            info "Parameter $SSH_PARAM is present but with the wrong value -- Fixing"
            replace_in_file "$CONF_FILE" "^$(echo "$CONF_LINE" | cut -d ' ' -f1)[[:space:]]*.*" "$CONF_LINE"
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
    if [ "$DEB_MAJ_VER" -ge "11" ]; then
        CONF_LINE_REGEX="ENCRYPT_METHOD (SHA512|yescrypt|YESCRYPT)"
        CONF_LINE="ENCRYPT_METHOD YESCRYPT"
    else
        CONF_LINE_REGEX="ENCRYPT_METHOD SHA512"
        CONF_LINE="ENCRYPT_METHOD SHA512"
    fi
    unset -f _set_vars_jit
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
