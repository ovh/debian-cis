#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure only strong Key Exchange algorithms are used (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Checking key exchange ciphers."

PACKAGE='openssh-server'
OPTIONS=''
FILE='/etc/ssh/sshd_config'
SSH_CRY_KEX_OK=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    is_pkg_installed "$PACKAGE"
    if [ "$FNRET" != 0 ]; then
        ok "$PACKAGE is not installed!"
        return
    else
        ok "$PACKAGE is installed"
        for SSH_OPTION in $OPTIONS; do
            SSH_PARAM=$(echo "$SSH_OPTION" | cut -d= -f 1)
            SSH_VALUE=$(echo "$SSH_OPTION" | cut -d= -f 2-)

            SSH_KEX_LINE=$($SUDO_CMD grep -i -- "^${SSH_PARAM}[[:space:]]" "$FILE" | tail -n 1)
            if [ -z "$SSH_KEX_LINE" ]; then
                crit "$SSH_PARAM is not present in $FILE"
                SSH_CRY_KEX_OK=1
                continue
            fi

            SSH_KEX_VALUE=$(echo "$SSH_KEX_LINE" | sed -E "s/^[[:space:]]*${SSH_PARAM}[[:space:]]+//I")
            SSH_KEX_NORMALIZED=$(echo "$SSH_KEX_VALUE" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

            local IFS=','
            for SSH_KEX in $SSH_VALUE; do
                SSH_KEX_REQUIRED=$(echo "$SSH_KEX" | tr '[:upper:]' '[:lower:]')
                case ",$SSH_KEX_NORMALIZED," in
                *",$SSH_KEX_REQUIRED,"*)
                    ok "$SSH_KEX is present in $FILE"
                    ;;
                *)
                    crit "$SSH_KEX is not present in $FILE"
                    SSH_CRY_KEX_OK=1
                    ;;
                esac
            done
        done

        if [ "$SSH_CRY_KEX_OK" -ne 0 ]; then
            crit "One or more required key exchange algorithms are not present in $FILE"
        fi
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$SSH_CRY_KEX_OK" = 0 ]; then
        ok "Required key exchange algorithms are already present in $FILE or package is not installed"
        return

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

        is_systemctl_running
        if [ "$FNRET" != 0 ]; then
            info "systemd is not running, skipping ssh reload"
            continue
        fi

        systemctl reload ssh >/dev/null 2>&1

    done
}

create_config() {
    # FIPS 140 approved according to debian 12 CIS
    KEX='ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256'
    cat <<EOF
status=audit
# Put your KexAlgorithms
OPTIONS="KexAlgorithms=$KEX"
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
