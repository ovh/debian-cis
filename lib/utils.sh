# CIS Debian 7 Hardening Utility functions



#
#   Return if a package is installed
#   @param $1 package name
#
is_installed()
{
    PKG_NAME=$1
    if `dpkg -s $PKG_NAME 2> /dev/null | grep -q '^Status: install '` ; then
        return 0
    fi
    return 1
}


# contains helper functions to work with apt

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
    LANGUAGE=C apt-get upgrade -s 2>/dev/null | grep -E "^Inst" > $DETAILS || : 
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
