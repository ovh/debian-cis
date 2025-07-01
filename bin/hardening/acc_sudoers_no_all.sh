#!/bin/bash

# run-shellcheck
#
# OVH Security audit
#

#
# Check there are no carte-blanche authorization in sudoers file(s).
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

# This function will be called if the script status is on enabled / audit mode
audit() {
    # expand spaces to [[:space:]]*
    # shellcheck disable=2001
    REGEX="$(echo "$REGEX" | sed 's/ /[[:space:]]*/g')"
    matched_files=""

    # check for pattern in $FILE
    if $SUDO_CMD grep -Eq "$REGEX" "$FILE"; then
        # Will log/warn below, once we've scanned everything,
        # because we must also check for patterns that are excused
        matched_files="$FILE"
    elif [ $? -gt 1 ]; then
        # ret > 1 means other grep error we must report
        crit "Couldn't grep for pattern in $FILE"
    else
        # no match, it's ok
        :
    fi

    # check for pattern in whole $DIRECTORY
    if $SUDO_CMD [ ! -d "$DIRECTORY" ]; then
        debug "$DIRECTORY does not exist"
    elif $SUDO_CMD [ ! -x "$DIRECTORY" ]; then
        crit "Cannot browse $DIRECTORY"
    else
        info "Will check for $($SUDO_CMD ls -f "$DIRECTORY" | wc -l) files within $DIRECTORY"
        matched_files="$matched_files $($SUDO_CMD grep -REl "$REGEX" "$DIRECTORY" || true)"
    fi

    # now check for pattern exceptions, and crit for each file otherwise
    for file in $matched_files; do
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
