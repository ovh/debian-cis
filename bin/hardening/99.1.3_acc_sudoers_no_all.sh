#!/bin/bash

# run-shellcheck
#
# OVH Security audit
#

#
# 99.1.3 Check there are no carte-blanche authorization in sudoers file(s).
#

set -e # One error, it's over
set -u # One variable unset, it's over

# shellcheck disable=2034
HARDENING_LEVEL=2
# shellcheck disable=2034
DESCRIPTION="Checks there are no carte-blanche authorization in sudoers file(s)."

FILE="/etc/sudoers"
DIRECTORY="/etc/sudoers.d"
# spaces will be expanded to [[:space:]]* when using the regex
# improves readability in audit report
REGEX="ALL = \( ALL( : ALL)? \)( NOPASSWD:)? ALL"
EXCEPT=""
MAX_FILES_TO_LOG=0

# This function will be called if the script status is on enabled / audit mode
audit() {
    # expand spaces to [[:space:]]*
    # shellcheck disable=2001
    REGEX="$(echo "$REGEX" | sed 's/ /[[:space:]]*/g')"

    local skiplog
    skiplog=0
    if [ $MAX_FILES_TO_LOG != 0 ]; then
        # if we have more than $MAX_FILES_TO_LOG files in $DIRECTORY, we'll reduce
        # logging in the loop, to avoid flooding the logs and getting timed out
        local nbfiles
        # shellcheck disable=2012 # (find is too slow and calls fstatat() for each file)
        nbfiles=$(ls -f "$DIRECTORY" | wc -l)
        if [ "$nbfiles" -gt "$MAX_FILES_TO_LOG" ]; then
            skiplog=1
            info "Found $nbfiles files in $DIRECTORY (> $MAX_FILES_TO_LOG), we won't log every file we check"
        fi
    fi

    FILES=""
    if $SUDO_CMD [ ! -r "$FILE" ]; then
        crit "$FILE is not readable"
        return
    fi
    FILES="$FILE"
    if $SUDO_CMD [ ! -d "$DIRECTORY" ]; then
        debug "$DIRECTORY does not exist"
    elif $SUDO_CMD [ ! -x "$DIRECTORY" ]; then
        crit "Cannot browse $DIRECTORY"
    else
        FILES="$FILES $($SUDO_CMD ls -1 $DIRECTORY | sed s=^=$DIRECTORY/=)"
    fi
    for file in $FILES; do
        if $SUDO_CMD [ ! -r "$file" ]; then
            crit "$file is not readable"
        else
            if ! $SUDO_CMD grep -E "$REGEX" "$file" &>/dev/null; then
                if [ $skiplog = 0 ]; then
                    ok "There is no carte-blanche sudo permission in $file"
                fi
            else
                RET=$($SUDO_CMD grep -E "$REGEX" "$file" | sed 's/\t/#/g;s/ /#/g')
                for line in $RET; do
                    if grep -q "$(echo "$line" | cut -d '#' -f 1)" <<<"$EXCEPT"; then
                        # shellcheck disable=2001
                        ok "$(echo "$line" | sed 's/#/ /g') is present in $file but was EXCUSED because $(echo "$line" | cut -d '#' -f 1) is part of exceptions."
                        continue
                    fi
                    # shellcheck disable=2001
                    crit "$(echo "$line" | sed 's/#/ /g') is present in $file"
                done
            fi
        fi
    done

}

# This function will be called if the script status is on enabled mode
apply() {
    :
}

# This function will create the config file for this check with default values
create_config() {
    cat <<EOF
status=audit

# Put EXCEPTION account names here, space separated
EXCEPT="root %root %sudo %wheel"

# If we find more than this amount of files in sudoers.d/,
# we'll reduce the logging in the loop to avoid getting
# timed out because we spend too much time logging.
# Using 0 disables this feature and will never reduce the
# logging, regardless of the number of files.
MAX_FILES_TO_LOG=0
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
