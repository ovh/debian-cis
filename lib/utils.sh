# shellcheck shell=bash
# CIS Debian Hardening Utility functions

# run-shellcheck

#
# Sysctl
#

has_sysctl_param_expected_result() {
    local SYSCTL_PARAM=$1
    local EXP_RESULT=$2

    # shellcheck disable=SC2319
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
    # shellcheck disable=SC2319
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
    local SYSCTL_VALUES SYSCTL_PARAM SYSCTL_EXP_RESULT

    local SYSCTL_PARAMS='net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1 net.ipv6.conf.lo.disable_ipv6=1'

    does_sysctl_param_exists "net.ipv6"
    local ENABLE=0
    if [ "$FNRET" = 0 ]; then
        for SYSCTL_VALUES in $SYSCTL_PARAMS; do
            SYSCTL_PARAM=$(echo "$SYSCTL_VALUES" | cut -d= -f 1)
            SYSCTL_EXP_RESULT=$(echo "$SYSCTL_VALUES" | cut -d= -f 2)
            has_sysctl_param_expected_result "$SYSCTL_PARAM" "$SYSCTL_EXP_RESULT"
            if [ "$FNRET" != 0 ]; then
                debug "$SYSCTL_PARAM was not set to $SYSCTL_EXP_RESULT"
                ENABLE=1
                break
            else
                debug "$SYSCTL_PARAM is set to $SYSCTL_EXP_RESULT"
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

is_file_empty() {
    local FILE=$1
    if $SUDO_CMD [ -s "$FILE" ]; then
        FNRET=1
    else
        FNRET=0
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

systemd_is_active_or_enabled() {
    local SYSTEMD_OBJECT=$1
    local SYSTEMD_OBJECT_TYPE=$2
    local SYSTEMD_ACTION=$3
    # if running in a container, it does not make much sense to test for systemd / service
    # the var "IS_CONTAINER" defined in lib/constant may not be enough, in case we are using systemd slices
    # currently, did not find a unified way to manage all cases, so we check this only for systemctl usage
    is_systemctl_running
    if [ "$FNRET" -eq 1 ]; then
        FNRET=1
        return
    fi

    if $SUDO_CMD systemctl -t "$SYSTEMD_OBJECT_TYPE" "$SYSTEMD_ACTION" "$SYSTEMD_OBJECT" >/dev/null; then
        FNRET=0
    else
        FNRET=1
    fi

}

is_service_enabled() {
    local SERVICE=$1

    systemd_is_active_or_enabled "$SERVICE" 'service' 'is-enabled'

    if [ "$FNRET" -eq 0 ]; then
        debug "Service $SERVICE is enabled"
    else
        debug "Service $SERVICE is not enabled"
    fi

}

is_service_active() {
    local SERVICE=$1

    systemd_is_active_or_enabled "$SERVICE" 'service' 'is-active'

    if [ "$FNRET" -eq 0 ]; then
        debug "Service $SERVICE is active"
    else
        debug "Service $SERVICE is not active"
    fi
}

is_socket_enabled() {
    local SOCKET=$1

    systemd_is_active_or_enabled "$SOCKET" 'socket' 'is-enabled'

    if [ "$FNRET" -eq 0 ]; then
        debug "Socket $SOCKET is enabled"
    else
        debug "Socket $SOCKET is not enabled"
    fi

}

is_socket_active() {
    local SOCKET=$1

    systemd_is_active_or_enabled "$SOCKET" 'socket' 'is-active'

    if [ "$FNRET" -eq 0 ]; then
        debug "Socket $SOCKET is active"
    else
        debug "Socket $SOCKET is not active"
    fi
}

is_timer_active() {
    local TIMER=$1

    systemd_is_active_or_enabled "$TIMER" 'timer' 'is-active'

    if [ "$FNRET" -eq 0 ]; then
        debug "Timer $TIMER is active"
    else
        debug "Timer $TIMER is not active"
    fi
}

is_timer_enabled() {
    local TIMER=$1

    systemd_is_active_or_enabled "$TIMER" 'timer' 'is-enabled'

    if [ "$FNRET" -eq 0 ]; then
        debug "Timer $TIMER is enabled"
    else
        debug "Timer $TIMER is not enabled"
    fi
}

#
# Kernel Options checks
#
is_kernel_monolithic() {
    debug "Detect if /proc/modules is available, otherwise consider as a monolithic kernel"
    if $SUDO_CMD ls /proc/modules >/dev/null 2>&1; then
        IS_MONOLITHIC_KERNEL=1
    else
        IS_MONOLITHIC_KERNEL=0
    fi
}

is_kernel_option_enabled() {
    # check if kernel option is configured for the running kernel
    local KERNEL_OPTION="$1"
    local RESULT=""

    is_kernel_monolithic

    if [ "$IS_MONOLITHIC_KERNEL" -eq 0 ] && $SUDO_CMD [ -r "/proc/config.gz" ]; then
        RESULT=$($SUDO_CMD zgrep "^$KERNEL_OPTION=" /proc/config.gz) || :
    fi

    # modular kernel, or no configuration found in /proc
    if [[ "$RESULT" == "" ]]; then
        if $SUDO_CMD [ -r "/boot/config-$(uname -r)" ]; then
            RESULT=$($SUDO_CMD grep "^$KERNEL_OPTION=" "/boot/config-$(uname -r)") || :
        else
            info "No information about kernel configuration found"
            FNRET=127
            return
        fi
    fi

    local ANSWER=""
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
}
is_kernel_module_disabled() {
    # check if a kernel module is disabled in the modprobe configuration
    local MODULE_NAME="$1"
    FNRET=1

    local module_is_disabled=0
    # is it blacklisted ?
    if grep -qE "\s?+[^#]?blacklist\s+$MODULE_NAME\s?$" /etc/modprobe.d/*.conf; then
        debug "$MODULE_NAME is blacklisted"
        module_is_disabled=1
    # maybe it is overriden ? check files in /etc/modprobe.d/ for "install xyz /bin/(true|false)"
    elif grep -qE "\s?+[^#]?install\s+$MODULE_NAME\s+/bin/(true|false)\s?$" /etc/modprobe.d/*.conf; then
        debug "$MODULE_NAME is disabled"
        module_is_disabled=1
    fi

    if [ "$module_is_disabled" -eq 1 ]; then
        debug "$MODULE_NAME is disabled in modprobe config"
        FNRET=0
    fi
}

is_kernel_module_available() {
    # check if a kernel module is loadable, in a non monolithic kernel

    local KERNEL_OPTION="$1"
    FNRET=1

    is_kernel_monolithic
    if [ "$IS_MONOLITHIC_KERNEL" -eq 0 ]; then
        info "your kernel is monolithic, no need to check for module availability"
        return
    fi

    # look if a module is present as a loadable module in ANY available kernel, per CIS recommendation
    # shellcheck disable=2013
    for config_file in $($SUDO_CMD grep -l "^$KERNEL_OPTION=" /boot/config-*); do
        module_config=$($SUDO_CMD grep "^$KERNEL_OPTION=" "$config_file" | cut -d= -f 2)
        if [ "$module_config" == 'm' ]; then
            debug "\"${KERNEL_OPTION}=m\" found in $config_file as module"
            FNRET=0
        fi
    done
}

is_kernel_module_loaded() {
    # check if a kernel module is actually loaded
    local KERNEL_OPTION="$1"
    local LOADED_MODULE_NAME="$2"
    FNRET=1

    is_kernel_monolithic
    if [ "$IS_MONOLITHIC_KERNEL" -eq 0 ]; then
        # check if module is compiled
        # if yes, then it is loaded
        is_kernel_option_enabled "$KERNEL_OPTION"
    elif $SUDO_CMD grep -w "$LOADED_MODULE_NAME" /proc/modules >/dev/null 2>&1; then
        debug "$LOADED_MODULE_NAME is loaded in the running kernel in /proc/modules"
        FNRET=0 # Found!
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

apt_remove() {
    local PACKAGE=$1
    DEBIAN_FRONTEND='noninteractive' apt-get remove -y "$PACKAGE"
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

is_pkg_a_dependency() {
    # check if a package is needed by another installed package
    # This is used to avoid removing a legit package while trying to remove an unwanted one
    local PKG_NAME=$1
    # ex: 'dnsmasq' is going to install 'dnsmasq-base'
    # We don't care about 'dnsmasq-base' here, we want to know about the others packages needing 'dnsmasq'
    # so we put 'dnsmasq-base' as a 'known_deps'
    shift
    local known_deps="$*"

    PKG_DEPENDENCIES=""
    # shellcheck disable=2162
    while read pkg_dep_name; do
        is_pkg_installed "$pkg_dep_name"
        if [ "$FNRET" -eq 0 ] && ! grep -w "$pkg_dep_name" <<<"$known_deps" >/dev/null; then
            PKG_DEPENDENCIES="$PKG_DEPENDENCIES $pkg_dep_name"
        fi

    done <<<"$(apt-cache rdepends "$PKG_NAME" | sed -e '1,2d' -e 's/^\ *//g' -e 's/^|//g' | sort -u)"

    if [ -n "$PKG_DEPENDENCIES" ]; then
        debug "$PKG_NAME is a dependency for some packages: $PKG_DEPENDENCIES"
        FNRET=0
    else
        debug "$PKG_NAME is not a dependency for another installed package"
        FNRET=1
    fi

}

# Returns Debian major version

get_debian_major_version() {
    DEB_MAJ_VER=""
    does_file_exist /etc/debian_version
    if [ "$FNRET" = 0 ]; then
        DEB_MAJ_VER=$(cut -d '.' -f1 /etc/debian_version)
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

is_systemctl_running() {
    FNRET=0
    if ! systemctl >/dev/null 2>&1; then
        debug "systemctl is not running"
        FNRET=1
    fi
}

manage_service() {
    local action="$1"
    local service="$2"

    is_systemctl_running
    if [ "$FNRET" -ne 0 ]; then
        return
    fi

    systemctl "$action" "$service" >/dev/null 2>&1

}
