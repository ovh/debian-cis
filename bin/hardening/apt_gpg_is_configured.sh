#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure GPG keys are configured (Manual)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure GPG keys are configured"
APT_KEY_PATH="/etc/apt/trusted.gpg.d"
APT_KEY_FILE="/etc/apt/trusted.gpg"
# Inspect effective global booleans through APT, rather than grepping configuration
# text: apt.conf uses quoted values and later files can override earlier ones.
apt_gpg_audit_options() {
    local option setting paths source_file findings
    local APT_GPG_SOURCE_LIST=/etc/apt/sources.list
    local APT_GPG_SOURCE_PARTS=/etc/apt/sources.list.d
    for option in Acquire::AllowInsecureRepositories Acquire::AllowWeakRepositories \
        Acquire::AllowDowngradeToInsecureRepositories APT::Get::AllowUnauthenticated; do
        if ! setting=$(apt-config shell APT_GPG_VALUE "$option/b"); then
            crit "Unable to read effective APT configuration"
            return
        fi
        if [ "$setting" = "APT_GPG_VALUE='true'" ]; then
            crit "$option disables part of APT authentication"
        fi
    done
    if ! paths=$(apt-config shell APT_GPG_SOURCE_LIST Dir::Etc::sourcelist/f \
        APT_GPG_SOURCE_PARTS Dir::Etc::sourceparts/d); then
        crit "Unable to locate APT sources"
        return
    fi
    # apt-config shell emits shell-escaped assignments (see apt-config(8)).
    eval "$paths"
    for source_file in "$APT_GPG_SOURCE_LIST" "$APT_GPG_SOURCE_PARTS"/*.list "$APT_GPG_SOURCE_PARTS"/*.sources; do
        if [ ! -e "$source_file" ]; then
            continue
        fi
        if [ "$source_file" != "$APT_GPG_SOURCE_LIST" ] && [[ ! "${source_file##*/}" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
            continue # APT ignores unsupported filenames in sourceparts.
        fi
        if [ ! -r "$source_file" ]; then
            crit "Cannot read APT source $source_file"
            continue
        fi
        if ! findings=$(awk '
            function trim(s) { sub(/^[ \t\r]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
            function yes(s) { return tolower(trim(s)) ~ /^(yes|true|1|on)$/ }
            function unsafe(k) { return k ~ /^(trusted|allow-insecure|allow-weak|allow-downgrade-to-insecure)$/ }
            function stanza( k) {
                if (tolower(trim(fields["enabled"])) !~ /^(no|false|0|off)$/) {
                    for (k in fields) if (unsafe(k) && yes(fields[k])) print k
                }
                for (k in fields) delete fields[k]
                field=""
            }
            FILENAME !~ /\.sources$/ {
                line=$0; sub(/#.*/, "", line)
                if (line !~ /^[ \t]*deb(-src)?[ \t]+\[/) next
                sub(/^[^[]*\[/, "", line); sub(/\].*$/, "", line)
                count=split(line, opts, /[ \t]+/)
                for (i=1; i<=count; i++) {
                    pos=index(opts[i], "=")
                    if (pos && unsafe(tolower(substr(opts[i], 1, pos-1))) && yes(substr(opts[i], pos+1))) print opts[i]
                }
                next
            }
            /^[ \t]*#/ { next }
            /^[ \t\r]*$/ { stanza(); next }
            /^[ \t]/ { if (field != "") fields[field]=fields[field] " " trim($0); next }
            {
                pos=index($0, ":")
                if (pos) {
                    field=tolower(substr($0, 1, pos-1))
                    fields[field]=trim(substr($0, pos+1))
                }
            }
            END { stanza() }
        ' "$source_file"); then
            crit "Unable to inspect APT source $source_file"
        elif [ -n "$findings" ]; then
            crit "Authentication bypass in $source_file: $findings"
        fi
    done
}

# This function will be called if the script status is on enabled / audit mode
audit() {
    apt_gpg_audit_options

    key_files=0
    info "Verifying that apt keys are present"
    # apt-key list requires that gnupg2 is installed
    # we are not going to install it for the sake of a test, so we only check the presence of key files
    is_file_empty "$APT_KEY_FILE"
    if [ "$FNRET" -eq 1 ]; then
        info "$APT_KEY_FILE present and not empty"
        key_files=$((key_files + 1))
    fi

    does_file_exist "$APT_KEY_PATH"
    if [ "$FNRET" -ne 0 ]; then
        info "$APT_KEY_PATH is missing"
    else
        asc_files=$(find "$APT_KEY_PATH" -name '*.asc' | wc -l)
        key_files=$((key_files + asc_files))

        gpg_files=$(find "$APT_KEY_PATH" -name '*.gpg' | wc -l)
        key_files=$((key_files + gpg_files))

        if [ "$asc_files" -eq 0 ] && [ "$gpg_files" -eq 0 ]; then
            info "No key found in $APT_KEY_PATH"
        fi
    fi

    if [ "$key_files" -eq 0 ]; then
        crit "No GPG file found"
    else
        info "Key material is present; repository key validity and ownership require manual review"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    info "This recommendation requires manual review and remediation of repository trust"
}

# This function will check config parameters required
check_config() {
    # No parameter for this script
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
