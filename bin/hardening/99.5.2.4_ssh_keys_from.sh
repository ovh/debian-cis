#!/bin/bash

# run-shellcheck
#
# OVH Security audit
#

#
# 99.5.2.4 Check <from> field in ssh authorized keys files for users with login shell, and bastions IP if available.
#

set -e # One error, it is over
set -u # One variable unset, it is over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Check <from> field in ssh authorized keys files for users with login shell, and allowed IP if available."

# Regex looking for empty, hash starting lines, or 'from="127.127.127,127.127.127" ssh'
# shellcheck disable=2089
REGEX_FROM_IP="from=(?:'|\")(,?(\d{1,3}(\.\d{1,3}){3}))+(?:'|\")"
REGEX_OK_LINES="(^(#|$)|($REGEX_FROM_IP))"
AUTHKEYFILE_PATTERN=""
AUTHKEYFILE_PATTERN_DEFAULT=".ssh/authorized_keys .ssh/authorized_keys2"

ALLOWED_IPS=""
USERS_TO_CHECK=""
EXCEPTION_USER=""

ALLOWED_NOLOGIN_SHELLS="/bin/false /usr/sbin/nologin"

# Check functions
check_ip() {
    file=$1
    if [ -z "$ALLOWED_IPS" ]; then
        warn "No allowed IPs to treat"
        return
    fi
    for line in $($SUDO_CMD grep -noP "$REGEX_FROM_IP" "$file" | tr -s " " | sed 's/ /_/g'); do
        linum=$(echo "$line" | cut -d ':' -f 1)
        ips=$(echo "$line" | cut -d '"' -f 2 | tr ',' ' ')
        ok_ips_allowed=""
        bad_ips=""
        for ip in $ips; do
            # shellcheck disable=SC2001
            ip_escaped=$(sed 's/\./\\./g' <<<"$ip")
            if grep -qw "$ip_escaped" <<<"$ALLOWED_IPS"; then
                debug "Line $linum of $file allows access from exused IP (${ip})."
                ok_ips_allowed+="$ip "
            else
                debug "Line $linum of $file allows access from ip ($ip) that is not allowed."
                bad_ips+="$ip "
            fi
        done
        # shellcheck disable=SC2001
        ok_ips=$(sed 's/ $//' <<<"${ok_ips_allowed}")
        # shellcheck disable=SC2001
        bad_ips=$(sed 's/ $//' <<<"${bad_ips}")
        if [[ -z "$bad_ips" ]]; then
            if [[ -n "$ok_ips" ]]; then
                ok "Line $linum of $file allows ssh access only from allowed IPs ($ok_ips)."
            fi
        else
            crit "Line $linum of $file allows ssh access from (${bad_ips}) that are not allowed."
            if [[ -n "$ok_ips" ]]; then
                ok "Line $linum of $file allows ssh access from at least allowed IPs ($ok_ips)."
            fi
        fi
    done
}

check_file() {
    file=$1
    if $SUDO_CMD [ ! -e "$file" ]; then
        debug "$file does not exist"
        return
    fi
    if $SUDO_CMD [ -r "$file" ]; then
        debug "Treating $file"
        FOUND_AUTHKF=1
        if $SUDO_CMD grep -vqP "$REGEX_OK_LINES" "${file}"; then
            bad_lines="$($SUDO_CMD grep -vnP "$REGEX_OK_LINES" "${file}" | cut -d ':' -f 1 | tr '\n' ' ' | sed 's/ $//')"
            crit "There are anywhere access keys in ${file} at lines (${bad_lines})."
        else
            ok "File ${file} is cleared from anywhere access keys."
            check_ip "$file"
        fi
    else
        crit "Cannot read ${file} for ${user}."
    fi
}

check_dir() {
    directory=$1
    if $SUDO_CMD [ ! -x "$directory" ]; then
        crit "Cannot read ${directory}."
        return
    fi
    for file in $AUTHKEYFILE_PATTERN; do
        check_file "${directory}"/"${file}"
    done
}

# This function will be called if the script status is on enabled / audit mode
audit() {
    # Retrieve authorized_key file pattern from sshd_config
    if $SUDO_CMD [ ! -r /etc/ssh/sshd_config ]; then
        crit "/etc/ssh/sshd_config is not readable."
    else
        ret=$($SUDO_CMD grep -iP "^AuthorizedKeysFile" /etc/ssh/sshd_config || echo '#KO')
        if [ "$ret" = "#KO" ]; then
            debug "No AuthorizedKeysFile defined in sshd_config."
        else
            AUTHKEYFILE_PATTERN=$(echo "$ret" | sed 's/AuthorizedKeysFile//i' | sed 's#%h/##' | tr -s "[:space:]")
            debug "Found pattern in sshdconfig : ${AUTHKEYFILE_PATTERN}."
        fi
    fi

    if [ -z "$AUTHKEYFILE_PATTERN" ]; then
        AUTHKEYFILE_PATTERN=$AUTHKEYFILE_PATTERN_DEFAULT
        debug "Set default pattern for authorized_keys file."
    fi

    if [ -z "$USERS_TO_CHECK" ]; then
        USERS_TO_CHECK=$($SUDO_CMD cat /etc/passwd | cut -d ":" -f 1)
        debug "Checking all users: $USERS_TO_CHECK"
    else
        debug "Checking only selected users: $USERS_TO_CHECK"
    fi

    for user in $USERS_TO_CHECK; do
        # Checking if at least one AuthKeyFile has been found for this user
        FOUND_AUTHKF=0
        shell=$(getent passwd "$user" | cut -d ':' -f 7)
        if grep -q "$shell" <<<"$ALLOWED_NOLOGIN_SHELLS"; then
            continue
        else
            info "User $user has a valid shell ($shell)."
            if [ "$user" = "root" ] && [ "$user" != "$EXCEPTION_USER" ]; then
                check_dir /root
                continue
            elif $SUDO_CMD [ ! -d /home/"$user" ]; then
                info "User $user has no home directory."
                continue
            fi
            check_dir /home/"${user}"
            if [ "$FOUND_AUTHKF" = 0 ]; then
                warn "$user has a valid shell but no authorized_keys file"
            fi
        fi

    done
}

# This function will be called if the script status is on enabled mode
apply() {
    :
}

create_config() {
    cat <<EOF
status=audit
# Put authorized IPs you want to allow in "from" field of authorized_keys
ALLOWED_IPS=""
USERS_TO_CHECK=""
EXCEPTION_USER=""
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
