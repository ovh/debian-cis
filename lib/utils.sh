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


