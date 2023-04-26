# shellcheck shell=bash
# CIS Debian Hardening Utility functions

# run-shellcheck

#
# Sysctl
#

has_sysctl_param_expected_result() {
    local SYSCTL_PARAM=$1
    local EXP_RESULT=$2

    if [ "$($SUDO_CMD sysctl "$SYSCTL_PARAM" 2>/dev/null)" = "$SYSCTL_PARAM = $EXP_RESULT" ]; then
        FNRET=0
    elif [ "$?" = 255 ]; then
        debug "$SYSCTL_PARAM does not exist"
        FNRET=255
    else
        debug "$SYSCTL_PARAM should be set to $EXP_RESULT"
        FNRET=1
    fi
}

does_sysctl_param_exists() {
    local SYSCTL_PARAM=$1
    if [ "$($SUDO_CMD sysctl -a 2>/dev/null | grep "$SYSCTL_PARAM" -c)" = 0 ]; then
        FNRET=1
    else
        FNRET=0
    fi
}

set_sysctl_param() {
    local SYSCTL_PARAM=$1
    local VALUE=$2
    debug "Setting $SYSCTL_PARAM to $VALUE"
    if [ "$(sysctl -w "$SYSCTL_PARAM"="$VALUE" 2>/dev/null)" = "$SYSCTL_PARAM = $VALUE" ]; then
        FNRET=0
    elif [ $? = 255 ]; then
        debug "$SYSCTL_PARAM does not exist"
        FNRET=255
    else
        warn "$SYSCTL_PARAM failed!"
        FNRET=1
    fi
}

#
# IPV6
#

is_ipv6_enabled() {
    SYSCTL_PARAMS='net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1 net.ipv6.conf.lo.disable_ipv6=1'

    does_sysctl_param_exists "net.ipv6"
    local ENABLE=1
    if [ "$FNRET" = 0 ]; then
        for SYSCTL_VALUES in $SYSCTL_PARAMS; do
            SYSCTL_PARAM=$(echo "$SYSCTL_VALUES" | cut -d= -f 1)
            SYSCTL_EXP_RESULT=$(echo "$SYSCTL_VALUES" | cut -d= -f 2)
            debug "$SYSCTL_PARAM should be set to $SYSCTL_EXP_RESULT"
            has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
            if [ "$FNRET" != 0 ]; then
                crit "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT"
                ENABLE=0
            fi
        done
    fi
    FNRET=$ENABLE
}

#
# Dmesg
#

does_pattern_exist_in_dmesg() {
    local PATTERN=$1
    if $SUDO_CMD dmesg | grep -qE "$PATTERN"; then
        FNRET=0
    else
        FNRET=1
    fi
}

#
# File
#

does_file_exist() {
    local FILE=$1
    if $SUDO_CMD [ -e "$FILE" ]; then
        FNRET=0
    else
        FNRET=1
    fi
}

has_file_correct_ownership() {
    local FILE=$1
    local USER=$2
    local GROUP=$3
    local USERID
    local GROUPID
    USERID=$(id -u "$USER")
    GROUPID=$(getent group "$GROUP" | cut -d: -f3)
    debug "$SUDO_CMD stat -c '%u %g' $FILE"
    if [ "$($SUDO_CMD stat -c "%u %g" "$FILE")" = "$USERID $GROUPID" ]; then
        FNRET=0
    else
        FNRET=1
    fi
}

has_file_one_of_ownership() {
    local FILE=$1
    local USER=$2
    local GROUPS_OK=$3

    local USEROK=1
    local GROUPOK=1

    local USERID
    USERID=$(id -u "$USER")
    if [ "$($SUDO_CMD stat -c "%u" "$FILE")" = "$USERID" ]; then
        USEROK=0
    fi

    for GROUP in $GROUPS_OK; do
        local GROUPID
        GROUPID=$(getent group "$GROUP" | cut -d: -f3)
        if [ "$($SUDO_CMD stat -c "%g" "$FILE")" = "$GROUPID" ]; then
            GROUPOK=0
        fi
    done

    if [[ "$GROUPOK" = 0 ]] && [[ "$USEROK" = 0 ]]; then
        FNRET=0
    else
        FNRET=1
    fi
}

has_file_correct_permissions() {
    local FILE=$1
    local PERMISSIONS=$2

    if [ "$($SUDO_CMD stat -L -c "%a" "$FILE")" = "$PERMISSIONS" ]; then
        FNRET=0
    else
        FNRET=1
    fi
}

has_file_one_of_permissions() {
    local FILE=$1
    local PERMISSIONS=$2
    FNRET=1
    for PERMISSION in $PERMISSIONS; do
        if [ "$($SUDO_CMD stat -L -c "%a" "$FILE")" = "$PERMISSION" ]; then
            FNRET=0
        fi
    done
}

does_pattern_exist_in_file_nocase() {
    _does_pattern_exist_in_file "-Ei" "$@"
}

does_pattern_exist_in_file() {
    _does_pattern_exist_in_file "-E" "$@"
}

_does_pattern_exist_in_file() {
    local OPTIONS="$1"
    shift
    local FILE="$1"
    shift
    local PATTERN="$*"

    debug "Checking if $PATTERN is present in $FILE"
    if $SUDO_CMD [ -r "$FILE" ]; then
        debug "$SUDO_CMD grep -q $OPTIONS -- '$PATTERN' $FILE"
        if $SUDO_CMD grep -q "$OPTIONS" -- "$PATTERN" "$FILE"; then
            debug "Pattern found in $FILE"
            FNRET=0
        else
            debug "Pattern NOT found in $FILE"
            FNRET=1
        fi
    else
        debug "File $FILE is not readable!"
        FNRET=2
    fi
}

get_db() {
    local DB="$1"
    $SUDO_CMD getent --service files "$DB"
}

# Look for pattern in file that can spread over multiple lines
# The func will remove commented lines (that begin with '#')
# and consider the file as one long line.
# Thus, this is not possible to look for pattern at beginning of line
# with this func ('^' and '$')
does_pattern_exist_in_file_multiline() {
    local FILE="$1"
    shift
    local PATTERN="$*"

    debug "Checking if multiline pattern: $PATTERN is present in $FILE"
    if $SUDO_CMD [ -r "$FILE" ]; then
        debug "$SUDO_CMD grep -v '^[[:space:]]*#' $FILE | tr '\n' ' ' | grep -Pq -- $PATTERN"
        if $SUDO_CMD grep -v '^[[:space:]]*#' "$FILE" | tr '\n' ' ' | grep -Pq -- "$PATTERN"; then
            debug "Pattern found in $FILE"
            FNRET=0
        else
            debug "Pattern NOT found in $FILE"
            FNRET=1
        fi
    else
        debug "File $FILE is not readable!"
        FNRET=2
    fi
}

add_end_of_file() {
    local FILE=$1
    local LINE=$2

    debug "Adding $LINE at the end of $FILE"
    backup_file "$FILE"
    echo "$LINE" >>"$FILE"
}

add_line_file_before_pattern() {
    local FILE=$1
    local LINE=$2
    local PATTERN=$3

    backup_file "$FILE"
    debug "Inserting $LINE before $PATTERN in $FILE"
    # shellcheck disable=SC2001
    PATTERN=$(sed 's@/@\\\/@g' <<<"$PATTERN")
    debug "sed -i '/$PATTERN/i $LINE' $FILE"
    sed -i "/$PATTERN/i $LINE" "$FILE"
    FNRET=0
}

replace_in_file() {
    local FILE=$1
    local SOURCE=$2
    local DESTINATION=$3

    backup_file "$FILE"
    debug "Replacing $SOURCE to $DESTINATION in $FILE"
    # shellcheck disable=SC2001
    SOURCE=$(sed 's@/@\\\/@g' <<<"$SOURCE")
    debug "sed -i 's/$SOURCE/$DESTINATION/g' $FILE"
    sed -i "s/$SOURCE/$DESTINATION/g" "$FILE"
    FNRET=0
}

delete_line_in_file() {
    local FILE=$1
    local PATTERN=$2

    backup_file "$FILE"
    debug "Deleting lines from $FILE containing $PATTERN"
    # shellcheck disable=SC2001
    PATTERN=$(sed 's@/@\\\/@g' <<<"$PATTERN")
    debug "sed -i '/$PATTERN/d' $FILE"
    sed -i "/$PATTERN/d" "$FILE"
    FNRET=0
}

#
# Users and groups
#

does_user_exist() {
    local USER=$1
    if getent passwd "$USER" >/dev/null 2>&1; then
        FNRET=0
    else
        FNRET=1
    fi
}

does_group_exist() {
    local GROUP=$1
    if getent group "$GROUP" >/dev/null 2>&1; then
        FNRET=0
    else
        FNRET=1
    fi
}

#
# Service Boot Checks
#

is_service_enabled() {
    local SERVICE=$1
    if [ "$($SUDO_CMD find /etc/rc?.d/ -name "S*$SERVICE" -print | wc -l)" -gt 0 ]; then
        debug "Service $SERVICE is enabled"
        FNRET=0
    else
        debug "Service $SERVICE is disabled"
        FNRET=1
    fi
}

#
# Kernel Options checks
#

is_kernel_option_enabled() {
    local KERNEL_OPTION="$1"
    local MODULE_NAME=""
    local MODPROBE_FILTER=""
    local RESULT=""
    local IS_MONOLITHIC_KERNEL=1
    local DEF_MODULE=""

    if [ $# -ge 2 ]; then
        MODULE_NAME="$2"
    fi

    if [ $# -ge 3 ]; then
        MODPROBE_FILTER="$3"
    fi

    debug "Detect if lsmod is available and does not return an error code (otherwise consider as a monolithic kernel"
    if $SUDO_CMD lsmod >/dev/null 2>&1; then
        IS_MONOLITHIC_KERNEL=0
    fi

    if [ $IS_MONOLITHIC_KERNEL -eq 1 ]; then
        if $SUDO_CMD [ -r "/proc/config.gz" ]; then
            RESULT=$($SUDO_CMD zgrep "^$KERNEL_OPTION=" /proc/config.gz) || :
        elif $SUDO_CMD [ -r "/boot/config-$(uname -r)" ]; then
            RESULT=$($SUDO_CMD grep "^$KERNEL_OPTION=" "/boot/config-$(uname -r)") || :
        else
            debug "No information about kernel found, you're probably in a container"
            FNRET=127
            return
        fi

        ANSWER=$(cut -d = -f 2 <<<"$RESULT")
        if [ "$ANSWER" = "y" ]; then
            debug "Kernel option $KERNEL_OPTION enabled"
            FNRET=0
        elif [ "$ANSWER" = "n" ]; then
            debug "Kernel option $KERNEL_OPTION disabled"
            FNRET=1
        else
            debug "Kernel option $KERNEL_OPTION not found"
            FNRET=2 # Not found
        fi

        if $SUDO_CMD [ "$FNRET" -ne 0 ] && [ -n "$MODULE_NAME" ] && [ -d "/lib/modules/$(uname -r)" ]; then
            # also check in modules, because even if not =y, maybe
            # the admin compiled it separately later (or out-of-tree)
            # as a module (regardless of the fact that we have =m or not)
            debug "Checking if we have $MODULE_NAME.ko"
            local modulefile
            modulefile=$($SUDO_CMD find "/lib/modules/$(uname -r)/" -type f -name "$MODULE_NAME.ko")
            if $SUDO_CMD [ -n "$modulefile" ]; then
                debug "We do have $modulefile!"
                # ... but wait, maybe it's blacklisted? check files in /etc/modprobe.d/ for "blacklist xyz"
                if grep -qRE "^\s*blacklist\s+$MODULE_NAME\s*$" /etc/modprobe.d/*.conf; then
                    debug "... but it's blacklisted!"
                    FNRET=1 # Not found (found but blacklisted)
                fi
                # ... but wait, maybe it's override ? check files in /etc/modprobe.d/ for "install xyz /bin/(true|false)"
                if grep -aRE "^\s*install\s+$MODULE_NAME\s+/bin/(true|false)\s*$" /etc/modprobe.d/*.conf; then
                    debug "... but it's override!"
                    FNRET=1 # Not found (found but override)
                fi
                FNRET=0 # Found!
            fi
        fi
    else
        if [ "$MODPROBE_FILTER" != "" ]; then
            DEF_MODULE="$($SUDO_CMD modprobe -n -v "$MODULE_NAME" 2>/dev/null | grep -E "$MODPROBE_FILTER" | tail -1 | xargs)"
        else
            DEF_MODULE="$($SUDO_CMD modprobe -n -v "$MODULE_NAME" 2>/dev/null | tail -1 | xargs)"
        fi

        if [ "$DEF_MODULE" == "install /bin/true" ] || [ "$DEF_MODULE" == "install /bin/false" ]; then
            debug "$MODULE_NAME is disabled (blacklist with override)"
            FNRET=1
        elif [ "$DEF_MODULE" == "" ]; then
            debug "$MODULE_NAME is disabled"
            FNRET=1
        else
            debug "$MODULE_NAME is enabled"
            FNRET=0
        fi

        if [ "$($SUDO_CMD lsmod | grep -E "$MODULE_NAME" 2>/dev/null)" != "" ]; then
            debug "$MODULE_NAME is enabled"
            FNRET=0
        fi
    fi
}

#
# Mounting point
#

# Verify $1 is a partition declared in fstab
is_a_partition() {
    local PARTITION=$1
    FNRET=128
    if [ ! -f /etc/fstab ] || [ -z "$(sed '/^#/d' /etc/fstab)" ]; then
        debug "/etc/fstab not found or empty, searching mountpoint"
        if mountpoint -q "$PARTITION"; then
            FNRET=0
        fi
    else
        if grep "[[:space:]]$1[[:space:]]" /etc/fstab | grep -vqE "^#"; then
            debug "$PARTITION found in fstab"
            FNRET=0
        elif mountpoint -q "$PARTITION"; then
            debug "$PARTITION found in /proc fs"
            FNRET=0
        else
            debug "Unable to find $PARTITION in fstab"
            FNRET=1
        fi

    fi
}

# Verify that $1 is mounted at runtime
is_mounted() {
    local PARTITION=$1
    if grep -q "[[:space:]]$1[[:space:]]" /proc/mounts; then
        debug "$PARTITION found in /proc/mounts, it's mounted"
        FNRET=0
    else
        debug "Unable to find $PARTITION in /proc/mounts"
        FNRET=1
    fi
}

# Verify $1 has the proper option $2 in fstab
has_mount_option() {
    local PARTITION=$1
    local OPTION=$2
    if [ ! -f /etc/fstab ] || [ -z "$(sed '/^#/d' /etc/fstab)" ]; then
        debug "/etc/fstab not found or empty, reading current mount options"
        has_mounted_option "$PARTITION" "$OPTION"
    else
        if grep "[[:space:]]${PARTITION}[[:space:]]" /etc/fstab | grep -vE "^#" | awk '{print $4}' | grep -q "bind"; then
            local actual_partition
            actual_partition="$(grep "[[:space:]]${PARTITION}[[:space:]]" /etc/fstab | grep -vE "^#" | awk '{print $1}')"
            debug "$PARTITION is a bind mount of $actual_partition"
            PARTITION="$actual_partition"
        fi
        if grep "[[:space:]]${PARTITION}[[:space:]]" /etc/fstab | grep -vE "^#" | awk '{print $4}' | grep -q "$OPTION"; then
            debug "$OPTION has been detected in fstab for partition $PARTITION"
            FNRET=0
        elif mountpoint -q "$PARTITION"; then
            debug "$OPTION not detected in fstab, but $PARTITION is a mount point searching in /proc fs"
            has_mounted_option "$PARTITION" "$OPTION"
        else
            debug "Unable to find $OPTION in fstab for partition $PARTITION"
            FNRET=1
        fi
    fi
}

# Verify $1 has the proper option $2 at runtime
has_mounted_option() {
    local PARTITION=$1
    local OPTION=$2
    if grep "[[:space:]]$1[[:space:]]" /proc/mounts | awk '{print $4}' | grep -q "$2"; then
        debug "$OPTION has been detected in /proc/mounts for partition $PARTITION"
        FNRET=0
    else
        debug "Unable to find $OPTION in /proc/mounts for partition $PARTITION"
        FNRET=1
    fi
}

# Setup mount option in fstab
add_option_to_fstab() {
    local PARTITION=$1
    local OPTION=$2
    debug "Setting $OPTION for $PARTITION in fstab"
    backup_file "/etc/fstab"
    # For example :
    # /dev/sda9       /home           ext4  auto,acl,errors=remount-ro  0       2
    # /dev/sda9       /home           ext4  auto,acl,errors=remount-ro,nodev  0       2
    debug "Sed command :  sed -ie \"s;\(.*\)\(\s*\)\s\($PARTITION\)\s\(\s*\)\(\w*\)\(\s*\)\(\w*\)*;\1\2 \3 \4\5\6\7,$OPTION;\" /etc/fstab"
    sed -ie "s;\(.*\)\(\s*\)\s\($PARTITION\)\s\(\s*\)\(\w*\)\(\s*\)\(\w*\)*;\1\2 \3 \4\5\6\7,$OPTION;" /etc/fstab
}

remount_partition() {
    local PARTITION=$1
    debug "Remounting $PARTITION"
    mount -o remount "$PARTITION"
}

#
# APT
#

apt_update_if_needed() {
    if [ -e /var/cache/apt/pkgcache.bin ]; then
        UPDATE_AGE=$(($(date +%s) - $(stat -c '%Y' /var/cache/apt/pkgcache.bin)))

        if [ "$UPDATE_AGE" -gt 21600 ]; then
            # update too old, refresh database
            $SUDO_CMD apt-get update -y >/dev/null 2>/dev/null
        fi
    else
        $SUDO_CMD apt-get update -y >/dev/null 2>/dev/null
    fi
}

apt_check_updates() {
    local NAME="$1"
    local DETAILS="/dev/shm/${NAME}"
    $SUDO_CMD apt-get upgrade -s 2>/dev/null | grep -E "^Inst" >"$DETAILS" || :
    local COUNT
    COUNT=$(wc -l <"$DETAILS")
    FNRET=128 # Unknown function return result
    RESULT="" # Result output for upgrade
    if [ "$COUNT" -gt 0 ]; then
        RESULT="There is $COUNT updates available :\n$(cat "$DETAILS")"
        FNRET=1
    else
        RESULT="OK, no updates available"
        FNRET=0
    fi
    rm "$DETAILS"
}

apt_install() {
    local PACKAGE=$1
    DEBIAN_FRONTEND='noninteractive' apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install "$PACKAGE" -y
    FNRET=0
}

#
#   Returns if a package is installed
#

is_pkg_installed() {
    PKG_NAME=$1
    if dpkg -s "$PKG_NAME" 2>/dev/null | grep -q '^Status: install '; then
        debug "$PKG_NAME is installed"
        FNRET=0
    else
        debug "$PKG_NAME is not installed"
        FNRET=1
    fi
}

# Returns Debian major version

get_debian_major_version() {
    DEB_MAJ_VER=""
    does_file_exist /etc/debian_version
    if [ "$FNRET" = 0 ]; then
        if grep -q "sid" /etc/debian_version; then
            DEB_MAJ_VER="sid"
        else
            DEB_MAJ_VER=$(cut -d '.' -f1 /etc/debian_version)
        fi
    else
        # shellcheck disable=2034
        DEB_MAJ_VER=$(lsb_release -r | cut -f2 | cut -d '.' -f 1)
    fi
}

# Returns the distribution

get_distribution() {
    DISTRIBUTION=""
    if [ -f /etc/os-release ]; then
        # shellcheck disable=2034
        DISTRIBUTION=$(grep "^ID=" /etc/os-release | sed 's/ID=//' | tr '[:upper:]' '[:lower:]')
        FNRET=0
    else
        debug "Distribution not found !"
        FNRET=127
    fi
}

# Detect if container based on cgroup detection

is_running_in_container() {
    awk -F/ '$2 == "'"$1"'"' /proc/self/cgroup
}
