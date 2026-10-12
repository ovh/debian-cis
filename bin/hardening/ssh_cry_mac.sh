#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure only strong MAC algorithms are used (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Checking Message Authentication Code ciphers for preferred UMAC and SHA-256|512 with Encrypt-Then-Mac (etm) setting."

PACKAGE='openssh-server'
OPTIONS=''
FILE='/etc/ssh/sshd_config'
SSH_CRY_MACS_OK=1

# This function will be called if the script status is on enabled / audit mode
audit() {
    SSH_CRY_MACS_OK=0

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed!"
    else
        ok "$PACKAGE is installed"
        for SSH_OPTION in $OPTIONS; do
            SSH_PARAM=$(echo "$SSH_OPTION" | cut -d= -f 1)
            SSH_VALUE=$(echo "$SSH_OPTION" | cut -d= -f 2-)

            SSH_MACS_LINE=$($SUDO_CMD grep -i -- "^${SSH_PARAM}[[:space:]]" "$FILE" | tail -n 1)
            if [ -z "$SSH_MACS_LINE" ]; then
                crit "$SSH_PARAM is not present in $FILE"
                SSH_CRY_MACS_OK=1
                continue
            fi

            SSH_MACS_VALUE=$(echo "$SSH_MACS_LINE" | sed -E "s/^[[:space:]]*${SSH_PARAM}[[:space:]]+//I")
            SSH_MACS_NORMALIZED=$(echo "$SSH_MACS_VALUE" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

            local IFS=','
            for SSH_MAC in $SSH_VALUE; do
                SSH_MAC_NORMALIZED=$(echo "$SSH_MAC" | tr '[:upper:]' '[:lower:]')
                case ",$SSH_MACS_NORMALIZED," in
                *",$SSH_MAC_NORMALIZED,"*)
                    ok "$SSH_MAC is present in $FILE"
                    ;;
                *)
                    crit "$SSH_MAC is not present in $FILE"
                    SSH_CRY_MACS_OK=1
                    ;;
                esac
            done
        done

        if [ "$SSH_CRY_MACS_OK" != 0 ]; then
            crit "One or more required MAC algorithms are not present in $FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SSH_CRY_MACS_OK" = 0 ]; then
        ok "Required MAC algorithms are already present in $FILE"
        return
    fi

    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" = 0 ]; then
        ok "$PACKAGE is installed"
    else
        crit "$PACKAGE is absent, installing it"
        apt_install "$PACKAGE"
    fi
    for SSH_OPTION in $OPTIONS; do
        SSH_PARAM=$(echo "$SSH_OPTION" | cut -d= -f 1)
        SSH_VALUE=$(echo "$SSH_OPTION" | cut -d= -f 2-)

        does_pattern_exist_in_file_nocase "$FILE" "^${SSH_PARAM}[[:space:]]"
        if [ "$FNRET" != 0 ]; then
            add_end_of_file "$FILE" "$SSH_PARAM $SSH_VALUE"
        else
            info "Parameter $SSH_PARAM is present but not fully compliant -- Fixing"
            replace_in_file "$FILE" "^${SSH_PARAM}[[:space:]]*.*" "$SSH_PARAM $SSH_VALUE"
        fi

        /etc/init.d/ssh reload >/dev/null 2>&1
    done

}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit
# Put your MACs
OPTIONS="MACs=hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256"
EOF
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
