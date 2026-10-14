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
OPTIONS='Storage=persistent'

journald_get_setting() {
    local file_path="$1"
    local setting_name="$2"

    awk -v key="$setting_name" '
        BEGIN { in_journal=0; value="" }
        /^[[:space:]]*\[Journal\][[:space:]]*$/ { in_journal=1; next }
        /^[[:space:]]*\[/ { in_journal=0; next }
        in_journal {
            line=$0
            sub(/#.*/, "", line)
            if (line ~ "^[[:space:]]*" key "[[:space:]]*=") {
                sub("^[[:space:]]*" key "[[:space:]]*=[[:space:]]*", "", line)
                sub(/[[:space:]]+$/, "", line)
                value=line
            }
        }
        END { print value }
    ' "$file_path"
}

journald_set_setting() {
    local file_path="$1"
    local setting_name="$2"
    local setting_value="$3"

    if [ ! -f "$file_path" ]; then
        printf '[Journal]\n%s=%s\n' "$setting_name" "$setting_value" >"$file_path"
        return
    fi

    sed -i "/^[[:space:]]*${setting_name}[[:space:]]*=.*/d" "$file_path"
    if ! grep -q '^\[Journal\]' "$file_path"; then
        sed -i '1i [Journal]' "$file_path"
    fi
    sed -i "/^\[Journal\]/a $setting_name=$setting_value" "$file_path"
}

build_journald_files_to_check() {
    JOURNALD_FILES_TO_CHECK="$FILE"
    if [ -d "$CONF_DIR" ]; then
        for config_file in "$CONF_DIR"/*; do
            [ -e "$config_file" ] || continue
            JOURNALD_FILES_TO_CHECK="$JOURNALD_FILES_TO_CHECK $config_file"
        done
    fi
}

# This function will be called if the script status is on enabled / audit mode
audit() {
    build_journald_files_to_check

    for JOURNALD_OPTION in $OPTIONS; do
        JOURNALD_PARAM=$(echo "$JOURNALD_OPTION" | cut -d= -f 1)
        JOURNALD_VALUE=$(echo "$JOURNALD_OPTION" | cut -d= -f 2)
        debug "$JOURNALD_PARAM should be set to $JOURNALD_VALUE"

        JOURNALD_EFFECTIVE_VALUE=""
        for JOURNALD_FILE in $JOURNALD_FILES_TO_CHECK; do
            if [ ! -r "$JOURNALD_FILE" ]; then
                continue
            fi
            JOURNALD_FILE_VALUE=$(journald_get_setting "$JOURNALD_FILE" "$JOURNALD_PARAM")
            if [ -n "$JOURNALD_FILE_VALUE" ]; then
                JOURNALD_EFFECTIVE_VALUE="$JOURNALD_FILE_VALUE"
            fi
        done

        if [ "$JOURNALD_EFFECTIVE_VALUE" = "$JOURNALD_VALUE" ]; then
            ok "$JOURNALD_PARAM is effectively set to $JOURNALD_VALUE in journald configuration"
        else
            crit "$JOURNALD_PARAM is not effectively set to $JOURNALD_VALUE in journald configuration"
        fi
    done
}

# This function will be called if the script status is on enabled mode
apply() {
    build_journald_files_to_check

    for JOURNALD_OPTION in $OPTIONS; do
        JOURNALD_PARAM=$(echo "$JOURNALD_OPTION" | cut -d= -f 1)
        JOURNALD_VALUE=$(echo "$JOURNALD_OPTION" | cut -d= -f 2)
        debug "$JOURNALD_PARAM should be set to $JOURNALD_VALUE"

        target_file=""
        JOURNALD_EFFECTIVE_VALUE=""
        for JOURNALD_FILE in $JOURNALD_FILES_TO_CHECK; do
            if [ ! -r "$JOURNALD_FILE" ]; then
                continue
            fi
            JOURNALD_FILE_VALUE=$(journald_get_setting "$JOURNALD_FILE" "$JOURNALD_PARAM")
            if [ -n "$JOURNALD_FILE_VALUE" ]; then
                JOURNALD_EFFECTIVE_VALUE="$JOURNALD_FILE_VALUE"
                target_file="$JOURNALD_FILE"
            fi
        done

        if [ "$JOURNALD_EFFECTIVE_VALUE" = "$JOURNALD_VALUE" ]; then
            ok "$JOURNALD_PARAM is effectively set to $JOURNALD_VALUE in journald configuration"
            continue
        fi

        warn "$JOURNALD_PARAM is not effectively set to $JOURNALD_VALUE in journald configuration, adding it"
        if [ -z "$target_file" ]; then
            info "Parameter $JOURNALD_PARAM seems absent from journald configuration, adding at the end of $FILE"
            journald_set_setting "$FILE" "$JOURNALD_PARAM" "$JOURNALD_VALUE"
        else
            info "Parameter $JOURNALD_PARAM is present but with the wrong value in $target_file -- Fixing"
            journald_set_setting "$target_file" "$JOURNALD_PARAM" "$JOURNALD_VALUE"
        fi
    done
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
