#!/bin/bash

# run-shellcheck
#
# CIS Debian Hardening
#

#
# Ensure pam_pwhistory module is enabled (Automated)
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=3
# shellcheck disable=2034
DESCRIPTION="Ensure use_authtok is enabled "

PAM_FILE="/etc/pam.d/common-password"
PAM_PATTERN="^[^#].*pam_unix.so.*use_authtok"

# this required libpam_pwquality package to be installed
# this should be covered by install_libpam_pwquality.sh

# This function will be called if the script status is on enabled / audit mode
audit() {
    PAM_VALID=1

    if $SUDO_CMD grep "$PAM_PATTERN" "$PAM_FILE" >/dev/null 2>&1; then
        ok "use_authtok is enabled"
        PAM_VALID=0
    else
        crit "use_authtok is not enabled"
    fi
}

# This function will be called if the script status is on enabled mode
apply() {
    if [ "$PAM_VALID" -ne 0 ]; then
        # we need to configure it in files present in /usr/share/pam-configs/, in the "Password" sections, but not in
        # the "Password-Initial" section
        local output_file="/$HOME/use_authtok_awk_output"
        local need_update=1

        for pam_file in /usr/share/pam-configs/*; do
            if grep 'Password:' "$pam_file" >/dev/null 2>&1 && grep pam_unix.so "$pam_file" >/dev/null 2>&1; then

                # if we are in section "Password", f=1
                # if we are in any section (line starting by any word ending with ':') but not in "Password" section, f=0
                # if f==1 then check for pam_unix.so and use_authtok, and add the later if absent
                # use a temporary file, as we can not replace in place
                awk '/Password:/ {f=1} /[a-zA-Z].*:/ && ! /Password:/ {f=0}  f{if (/pam_unix\.so/ && ! /use_authtok/) sub("obscure","obscure use_authtok")} {print}' "$pam_file" >"$output_file"

                pam_file_basename=$(basename "$pam_file")

                info "backup $pam_file to $HOME"
                mv "$pam_file" "$HOME"/"$pam_file_basename"_"$(date +%s)"
                info "replace $pam_file"
                mv "$output_file" "$pam_file"
                rm -f "$output_file"

                need_update=0
            fi
        done

        if [ "$need_update" -eq 0 ]; then
            # on debian12 even --force wont update the common-password file
            # it has to be removed an re-created
            bkp_file="$PAM_FILE"_"$(date +%s)"
            info "backup $PAM_FILE to $bkp_file"
            mv "$PAM_FILE" "$bkp_file"

            info "Applying 'pam-auth-update' to enable use_authtok"
            DEBIAN_FRONTEND='noninteractive' pam-auth-update --force --enable
            # shellcheck disable=2181
            if [ $? -eq 0 ]; then
                info "update successful, removing backup file"
                rm -f "$bkp_file"
            else
                info "update failed, restoring backup file"
                mv "$bkp_file" "$PAM_FILE"
            fi
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
