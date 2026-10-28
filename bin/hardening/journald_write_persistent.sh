#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure journald is configured to write logfiles to persistent disk (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Configure journald to write to a persistent location."

FILE='/etc/systemd/journald.conf'
CONF_DIR='/etc/systemd/journald.conf.d'

JOURNALD_STORAGE_EFFECTIVE_VALUE=""
JOURNALD_STORAGE_TARGET_FILE=""
JOURNALD_STORAGE_NEEDS_FIX=1

build_journald_files_to_check() {
    JOURNALD_FILES_TO_CHECK="$FILE"
    if [ -d "$CONF_DIR" ]; then
        # journald only reads *.conf drop-ins
        for config_file in "$CONF_DIR"/*.conf; do
            [ -e "$config_file" ] || continue
            JOURNALD_FILES_TO_CHECK="$JOURNALD_FILES_TO_CHECK $config_file"
        done
    fi
}

# This function will be called if the script status is on enabled / audit mode
audit() {
    build_journald_files_to_check

    # as for journald, the last file defining the setting wins
    for JOURNALD_FILE in $JOURNALD_FILES_TO_CHECK; do
        if [ ! -r "$JOURNALD_FILE" ]; then
            continue
        fi
        JOURNALD_FILE_VALUE=$(get_journald_setting "$JOURNALD_FILE" "Storage")
        if [ -n "$JOURNALD_FILE_VALUE" ]; then
            JOURNALD_STORAGE_EFFECTIVE_VALUE="$JOURNALD_FILE_VALUE"
            JOURNALD_STORAGE_TARGET_FILE="$JOURNALD_FILE"
        fi
    done

    if [ "$JOURNALD_STORAGE_EFFECTIVE_VALUE" = "persistent" ]; then
        JOURNALD_STORAGE_NEEDS_FIX=0
        ok "Storage is effectively set to persistent in journald configuration"
    else
        crit "Storage is not effectively set to persistent in journald configuration"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$JOURNALD_STORAGE_NEEDS_FIX" -ne 0 ]; then
        warn "Storage is not effectively set to persistent in journald configuration, fixing it"
        if [ -n "$JOURNALD_STORAGE_EFFECTIVE_VALUE" ]; then
            info "Effective value is $JOURNALD_STORAGE_EFFECTIVE_VALUE; updating the active journald entry"
        else
            info "Effective value is unset; adding the journald setting"
        fi
        if [ -n "$JOURNALD_STORAGE_TARGET_FILE" ]; then
            info "Parameter Storage is present but with the wrong value in $JOURNALD_STORAGE_TARGET_FILE -- Fixing"
            set_journald_setting "$JOURNALD_STORAGE_TARGET_FILE" "Storage" "persistent"
        else
            info "Parameter Storage seems absent from journald configuration, adding it to $FILE"
            set_journald_setting "$FILE" "Storage" "persistent"
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
