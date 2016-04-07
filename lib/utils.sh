# CIS Debian 7 Hardening Utility functions

#
# File manipulation
#

does_file_exist() {
    local FILE=$1
    if [ -e $FILE ]; then
        FNRET=0
    else
        FNRET=1
    fi
}

has_file_correct_ownership() {
    local FILE=$1
    local USER=$2
    local GROUP=$3
    local USERID=$(id -u $USER)
    local GROUPID=$(id -u $GROUP)

    if [ "$(stat -c "%u %g" /boot/grub/grub.cfg)" = "$USERID $GROUPID" ]; then
        FNRET=0
    else
        FNRET=1
    fi
}

#
# User manipulation
#

does_user_exist() {
    local USER=$1
    if $(getent passwd $USER >/dev/null 2>&1); then
        FNRET=0
    else
        FNRET=1
    fi
}

does_group_exist() {
    local GROUP=$1
    if $(getent group $GROUP >/dev/null 2>&1); then
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
    if [ $(find /etc/rc?.d/ -name "S*$SERVICE" -print | wc -l) -gt 0 ]; then
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
    local KERNEL_OPTION=$1
    RESULT=$(zgrep -i $KERNEL_OPTION /proc/config.gz | grep -vE "^#") || :
    ANSWER=$(cut -d = -f 2 <<< $RESULT)
    if [ "x$ANSWER" = "xy" ]; then
        debug "Kernel option $KERNEL_OPTION enabled"
        FNRET=0
    elif [ "x$ANSWER" = "xn" ]; then
        debug "Kernel option $KERNEL_OPTION disabled"
        FNRET=1
    else
        debug "Kernel option $KERNEL_OPTION not found"
        FNRET=2 # Not found
    fi
}

#
# Mounting point manipulation
#

# Verify $1 is a partition declared in fstab
is_a_partition() {

    local PARTITION_NAME=$1
    FNRET=128
    if $(grep "[[:space:]]$1[[:space:]]" /etc/fstab | grep -vqE "^#"); then
        debug "$PARTITION found in fstab"
        FNRET=0
    else
        debug "Unable to find $PARTITION in fstab"
        FNRET=1
    fi
}

# Verify that $1 is mounted at runtime
is_mounted() {
    local PARTITION_NAME=$1
    if $(grep -q "[[:space:]]$1[[:space:]]" /proc/mounts); then
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
    if $(grep "[[:space:]]$1[[:space:]]" /etc/fstab | grep -vE "^#" | awk {'print $4'} | grep -q "$2"); then
        debug "$OPTION has been detected in fstab for partition $PARTITION"
        FNRET=0
    else
        debug "Unable to find $OPTION in fstab for partition $PARTITION"
        FNRET=1
    fi
}

# Verify $1 has the proper option $2 at runtime
has_mounted_option() {
    local PARTITION=$1
    local OPTION=$2
    if $(grep "[[:space:]]$1[[:space:]]" /proc/mounts | awk {'print $4'} | grep -q "$2"); then
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
    mount -o remount $PARTITION
}

#
# Helper functions to work with apt
#

apt_update_if_needed() 
{
    if [ -e /var/cache/apt/pkgcache.bin ]
    then
        UPDATE_AGE=$(( $(date +%s) - $(stat -c '%Y'  /var/cache/apt/pkgcache.bin)  ))

        if [ $UPDATE_AGE -gt 21600 ]
        then
            # update too old, refresh database
            apt-get update -y >/dev/null 2>/dev/null
        fi
    else
        apt-get update -y >/dev/null 2>/dev/null
    fi
}

apt_check_updates()
{
    local NAME="$1"
    local DETAILS="/dev/shm/${NAME}"
    apt-get upgrade -s 2>/dev/null | grep -E "^Inst" > $DETAILS || : 
    local COUNT=$(wc -l < "$DETAILS")
    FNRET=128 # Unknown function return result
    RESULT="" # Result output for upgrade
    if [ $COUNT -gt 0 ]; then
        RESULT="There is $COUNT updates available :\n$(cat $DETAILS)"
        FNRET=1
    else
        RESULT="OK, no updates available"
        FNRET=0
    fi
    rm $DETAILS
}

#
#   Returns if a package is installed
#

is_installed()
{
    PKG_NAME=$1
    if `dpkg -s $PKG_NAME 2> /dev/null | grep -q '^Status: install '` ; then
        FNRET=0
    fi
    FNRET=1
}
