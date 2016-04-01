# CIS Debian 7 Hardening common functions

# Logging functions

case $LOGLEVEL in
    error )
        MACHINE_LOG_LEVEL=1
        ;;
    warning )
        MACHINE_LOG_LEVEL=2
        ;;
    info )
        MACHINE_LOG_LEVEL=3
        ;;
    debug )
        MACHINE_LOG_LEVEL=4
        ;;
    *)
        MACHINE_LOG_LEVEL=3 ## Default loglevel value to info
esac

_logger() {
    COLOR=$1
    shift
    test -z "$SCRIPT_NAME" && SCRIPT_NAME=$(basename $0)
    /usr/bin/logger -t "[CIS_Hardening] $SCRIPT_NAME" -p "user.info" "$*"
    test -t 1 && cecho $COLOR "$SCRIPT_NAME $*"
}

cecho () {
    COLOR=$1
    shift
    echo -e "${COLOR}$*${NC}"
}

info () { 
    [ $MACHINE_LOG_LEVEL -ge 3 ] && _logger $BWHITE "[INFO] $*"
}

warn () {
    [ $MACHINE_LOG_LEVEL -ge 2 ] && _logger $BYELLOW "[WARN] $*"
}

crit () {
    [ $MACHINE_LOG_LEVEL -ge 1 ] && _logger $BRED "[ KO ] $*"
}

debug () {
    [ $MACHINE_LOG_LEVEL -ge 4 ] && _logger $GRAY "[DBG ] $*"
}
